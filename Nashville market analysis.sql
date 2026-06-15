-- Preview raw dataset
select * from nashville;

-- Since we imported everthing as text, we need to do some cleaning
-- HANDLING BLANK VALUES . we will convert '' -> NULL so that MySQL can properly recognize data

select * from nashville where trim(ParcelID) = '';
update nashville set ParcelID = NULL where trim(ParcelID) = '';

select * from nashville where trim(PropertyAddress) = '';
update nashville set PropertyAddress = NULL where trim(PropertyAddress) = '';

select * from nashville where trim(SaleDate) = '';
update nashville set SaleDate = NULL where trim(SaleDate) = '';

select * from nashville where trim(SalePrice) = '';
update nashville set SalePrice = NULL where trim(SalePrice) = '';

select * from nashville where trim(OwnerAddress) = '';
update nashville set OwnerAddress = NULL where trim(OwnerAddress) = '';

select * from nashville where trim(Acreage) = '';
update nashville set Acreage = NULL where trim(Acreage) = '';

select * from nashville where trim(LandValue) = '';
update nashville set LandValue = NULL where trim(LandValue) = '';

select * from nashville where trim(BuildingValue) = '';
update nashville set BuildingValue = NULL where trim(BuildingValue) = '';

select * from nashville where trim(TotalValue) = '';
update nashville set TotalValue = NULL where trim(TotalValue) = '';

select * from nashville where trim(YearBuilt) = '';
update nashville set YearBuilt = NULL where trim(YearBuilt) = '';

select * from nashville where trim(Bedrooms) = '';
update nashville set Bedrooms = NULL where trim(Bedrooms) = '';

select * from nashville where trim(FullBath) = '';
update nashville set FullBath = NULL where trim(FullBath) = '';

select * from nashville where trim(HalfBath) = '';
update nashville set HalfBath = NULL where trim(HalfBath) = '';

select * from nashville;




-- =================================================================
-- Standardizing the date format

-- right now "SaleDate" is in text format. we will convert it to date
-- (ex:  "April 11,2013") into MySQL DATE format (2013-04-11)


select SaleDate, str_to_date(SaleDate, '%M %e,%Y')
from nashville;

update nashville
set SaleDate = str_to_date(SaleDate, '%M %e,%Y');

alter table nashville modify SaleDate DATE;



-- =================================================================
-- Populating missing "PropertyAddress" 

-- here's how we will do it:
-- some records have missing PropertyAddress values. properties with the same ParcelID represent the
-- same property, so we can use the address from another matching ParcelID record

-- we will use self join 

select t1.ParcelID, t1.PropertyAddress, t2.ParcelID, t2.PropertyAddress
from nashville t1
join nashville t2
	on t1.parcelID = t2.parcelID and t1.uniqueID <> t2.uniqueID
where t1.PropertyAddress is null and t2.PropertyAddress is not null;


-- Filling missing PropertyAddress values using matching ParcelID records

update nashville t1
join nashville t2
    on t1.ParcelID = t2.ParcelID
   and t1.UniqueID <> t2.UniqueID
set t1.PropertyAddress = t2.PropertyAddress
where t1.PropertyAddress is null
  and t2.PropertyAddress is not null;
update nashville t1
join nashville t2
	on t1.parcelID = t2.parcelID and t1.uniqueID <> t2.uniqueID
set t1.PropertyAddress = t2.PropertyAddress
where t1.PropertyAddress is null and t2.PropertyAddress is not null;




-- =================================================================

-- Splitting PropertyAddress into separate columns (address, city, state)

select PropertyAddress, substr(PropertyAddress, 1, locate(',',PropertyAddress) -1),
		substr(PropertyAddress,locate(',',PropertyAddress)+1)
from nashville;


alter table nashville add PropertySplitAddress varchar(255);
alter table nashville add PropertySplitCity varchar(255);

update nashville 
set PropertySplitAddress = substr(PropertyAddress, 1, locate(',',PropertyAddress) -1);

update nashville
set PropertySplitCity = substr(PropertyAddress,locate(',',PropertyAddress)+1);

select * from nashville; 


-- Now we will do it with OwnerAddress. this time we will use substring_index()
-- substring_index(string, delimiter, count)

select OwnerAddress,
		substring_index(OwnerAddress,',',1),
        substring_index(substring_index(OwnerAddress,',',2),',',-1),
        substring_index(OwnerAddress,',',-1)
from nashville;


alter table nashville add OwnerSplitAddress varchar(255);
alter table nashville add OwnerSplitCity varchar(255);
alter table nashville add OwnerSplitState varchar(255);

update nashville   
set OwnerSplitAddress = substring_index(OwnerAddress,',',1);

update nashville
set  OwnerSplitCity = substring_index(substring_index(OwnerAddress,',',2),',',-1);

update nashville
set OwnerSplitState = substring_index(OwnerAddress,',',-1);

select * from nashville;





-- =================================================================

-- Standardizing categorical values

-- converting : 'Y' -> 'Yes' and 'N' -> no , in SoldAsVacant column

select distinct SoldAsVacant from nashville; 

select distinct SoldAsVacant, count(*) from nashville
group by SoldAsVacant
order by 2;  


select SoldAsVacant,
CASE 
	WHEN SoldAsVacant = 'Y' THEN 'Yes'
    WHEN SoldAsVacant = 'N' THEN 'No'
    ELSE SoldAsVacant
END
from nashville 
order by 1;


update nashville
set SoldAsVacant = CASE 
	WHEN SoldAsVacant = 'Y' THEN 'Yes'
    WHEN SoldAsVacant = 'N' THEN 'No'
    ELSE SoldAsVacant
END;
    



-- =================================================================

-- Identifying duplicate values


-- We will use cte's and window functions 
-- Duplicate criteria:
	-- ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference
-- The first occurrence receives row_num = 1.
-- All additional occurrences are considered duplicates.


with row_num_cte as(
	select *,
		row_number() over(partition by ParcelID, PropertyAddress, 
						SalePrice, SaleDate, LegalReference 
						order by UniqueID) row_num 
	from nashville
	order by ParcelID
)
select *
from row_num_cte
where row_num > 1
order by PropertyAddress; 


-- Removing duplicate records

-- We cant directly delete form a cte on mysql
-- So we will use joins



-- METHOD-1 (NOT RECOMMENDED)

select *
from nashville t1
join nashville t2
	on t1.ParcelID = t2.ParcelID
    and t1.PropertyAddress = t2.PropertyAddress
    and t1.SalePrice = t2.SalePrice
    and t1.SaleDate = t2.SaleDate
    and t1.LegalReference = t2.LegalReference
    and t1.UniqueID > t2.UniqueID;


delete t1
from nashville t1
join nashville t2
	on t1.ParcelID = t2.ParcelID
    and t1.PropertyAddress = t2.PropertyAddress
    and t1.SalePrice = t2.SalePrice
    and t1.SaleDate = t2.SaleDate
    and t1.LegalReference = t2.LegalReference
    and t1.UniqueID > t2.UniqueID;
    
	-- If two rows have the same ParcelID, PropertyAddress, SalePrice, SaleDate, and LegalReference
	-- then keep the row with the smallest UniqueID and delete the duplicate rows.
	-- This method is not recommended. Since we are woring with a large dataset(~58000 rows)
    -- So using joins will increase the time complexity exponentially.
    
    
    
    
-- METHOD 2 (USING TEMPORARY TABLE)

create temporary table dupes as
with row_num_cte as(
	select UniqueID,
		row_number() over(
			partition by ParcelID, 
						 PropertyAddress, 
						 SalePrice, 
                         SaleDate, 
                         LegalReference 
			order by UniqueID) as row_num 
	from nashville
)
select *
from row_num_cte
where row_num > 1;

select count(*) from dupes;



-- Deleting duplicate rows from nashville by matching UniqueIDs found in the temporary table.

delete n
from nashville n
join dupes d
    on n.UniqueID = d.UniqueID;

-- Now all the duplicates are removed




-- =================================================================

-- After creating cleaned and split columns, the original columns are no longer needed.
-- Removing redundant fields helps improve table readability and reduces storage usage.


select * from nashville;

alter table nashville  
drop column PropertyAddress,
drop column TaxDistrict,
drop column OwnerAddress;

describe nashville;




-- =================================================================
-- PROJECT COMPLETE
-- =================================================================
-- Data Cleaning Tasks Performed:
		-- Replaced blank values with NULLs
		-- Standardized date formats
		-- Populated missing PropertyAddress values
		-- Split PropertyAddress into Address & City
		-- Split OwnerAddress into Address, City & State
		-- Standardized SoldAsVacant values
		-- Identified and removed duplicate records
		-- Dropped unnecessary columns
        
-- Result:
		-- Clean, analysis-ready Nashville Housing dataset.
-- =================================================================

























































































































































