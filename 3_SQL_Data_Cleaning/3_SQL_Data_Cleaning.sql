-- Welcome, today we'll do some data cleaning in SQL using a dataset called Nashville Housing
-- There is also a pdf containing pictures so readers can understand the steps in context easier, refer the picture numbering in the query to the pdf

-- 1. First, almost like a tradition let's bring up the whole data to see what we're dealing with
select * from Nashville_Housing (Pic 1)

-- Right up, we can already see a potentially dirty dataset that wouldn't mind a bit of 'cleaning'

-- 2. Standardizing the Date format
-- The SaleDate column data is datetime, time of the day isn't really necessary so let's change it to just date
alter table Nashville_Housing
add SaleDateConverted date;

update Nashville_Housing
set SaleDateConverted = convert(date, SaleDate)

-- 56477 rows affected! Now just to check
select SaleDateConverted 
from Nashville_Housing
-- It exists, good

-- 3. Populating nulls in PropertyAddress data
-- One can only wonder why a property listing data has nulls in the address, so let's try find a way to populate the nulls
-- Cutting to the chase, turns out each key in the ParcelID column can occur several times with at least one has the address data
select a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, 
	isnull(a.PropertyAddress, b.PropertyAddress) as PropertyAddressFix
from Nashville_Housing a
join Nashville_Housing b
	on a.ParcelID = b.ParcelID
	and a.[UniqueID ] <> b.[UniqueID ]
where a.PropertyAddress is null (Pic 3.1)
-- The idea is to populate the null addresses with the PropertyAddressFix values

-- Now to update the values into the original data
update a 
set PropertyAddress = isnull(a.PropertyAddress, b.PropertyAddress)
from Nashville_Housing a
join Nashville_Housing b
	on a.ParcelID = b.ParcelID
	and a.[UniqueID ] <> b.[UniqueID ]
where a.PropertyAddress is null (Pic 3.2)
-- 29 rows affected, that's the correct count of the nulls
-- Just to check, the query below should return nothing
select * from Nashville_Housing
where PropertyAddress is null

-- 4. Breaking PropertyAddress into individual columns (City, State, Address)
-- Simply put, break the PropertyAddress into two separate columns using substring
-- First let's run our query that breaks the value based on a comma delimiter
select substring(PropertyAddress, 1, charindex(',', PropertyAddress)-1) as Address,
		substring(PropertyAddress, charindex(',', PropertyAddress)+1, len(PropertyAddress)) as City
from Nashville_Housing (Pic 4.1)

-- The query gives our desired output, so let's add the columns and fill the values accordingly
alter table Nashville_Housing
add Property_Address nvarchar(255);

update Nashville_Housing
set Property_Address = substring(PropertyAddress, 1, charindex(',', PropertyAddress)-1)

alter table Nashville_Housing
add Property_City nvarchar(255);

update Nashville_Housing
set Property_City = substring(PropertyAddress, charindex(',', PropertyAddress)+1, len(PropertyAddress))

-- After running the queries above in order, let's check just to make sure
select PropertyAddress, Property_Address, Property_City
from Nashville_Housing (Pic 4.2)

-- 5. Breaking the Owner Address into individual columns
-- Similarly, we'll do the same to OwnerAddress but with a different method called parsing
select OwnerAddress,
	 parsename(replace(OwnerAddress, ',', '.'), 1),
	 parsename(replace(OwnerAddress, ',', '.'), 2),
	 parsename(replace(OwnerAddress, ',', '.'), 3)
from Nashville_Housing (Pic 5.1)

-- Now to add in the columns and its values into the table
alter table Nashville_Housing
add Owner_Address nvarchar(255);

update Nashville_Housing
set Owner_Address = parsename(replace(OwnerAddress, ',', '.'), 3)

alter table Nashville_Housing
add Owner_City nvarchar(255);

update Nashville_Housing
set Owner_City = parsename(replace(OwnerAddress, ',', '.'), 2)

alter table Nashville_Housing
add Owner_State nvarchar(255);

update Nashville_Housing
set Owner_State = parsename(replace(OwnerAddress, ',', '.'), 1)

-- Again, checking won't hurt
select OwnerAddress, Owner_Address, Owner_City, Owner_State
from Nashville_Housing (Pic 5.2)

-- 6. Changing 'Y' and 'N' to 'Yes' and 'No' in SoldAsVacant

select distinct(SoldAsVacant), count(SoldasVacant)
from Nashville_Housing
group by SoldAsVacant
order by 2
-- We can see that there are 4 unique values, where we want only 'Yes' and 'No' values

-- First, we try make a query for converting the 'Y' and 'N'
select SoldAsVacant,
case when SoldAsVacant = 'Y' then 'Yes'
	 when SoldAsVacant = 'N' then 'No'
	 else SoldAsVacant
	 end
from Nashville_Housing (Pic 6)

-- As the query worked, next we update the SoldAsVacant values in the table
update Nashville_Housing
set SoldAsVacant = case when SoldAsVacant = 'Y' then 'Yes'
					when SoldAsVacant = 'N' then 'No'
					else SoldAsVacant
					end
-- To check, rerun the first query to confirm there are only 2 distinct values

-- 7. Removing Duplicates
-- There are a lot of duplicate rows in the data, and we want to remove it
-- It's not common to alter the data by deleting a part or the whole of it permanently, so make sure we have the green light before we run these queries
select *,
ROW_NUMBER() over (
				partition by ParcelID,
							 PropertyAddress,
							 SaleDate,
							 SalePrice,
							 LegalReference
							 order by UniqueID
				  ) row_num
from Nashville_Housing
order by ParcelID

-- The logic goes: if there are 2 rows of data where all the column features are all the same, well that can't be right
-- Now we modify the query into a CTE so we can add conditions

with row_num_cte as 
(
select *,
ROW_NUMBER() over (
				partition by ParcelID,
							 PropertyAddress,
							 SaleDate,
							 SalePrice,
							 LegalReference
							 order by UniqueID
				  ) row_num
from Nashville_Housing
)
select * 
from row_num_cte 
where row_num > 1
order by PropertyAddress (Pic 7)

-- Executing the row_num_cte returns data that are classified as duplicates
-- Now we simply delete said data

with row_num_cte as 
(
select *,
ROW_NUMBER() over (
				partition by ParcelID,
							 PropertyAddress,
							 SaleDate,
							 SalePrice,
							 LegalReference
							 order by UniqueID
				  ) row_num
from Nashville_Housing
)
delete
from row_num_cte 
where row_num > 1

-- '104 rows affected' now we rerun the row_num_cte, nothing should come up

-- 8. Deleting Unused Columns 
-- Again, these steps should only be done if it is allowed to alter the raw data, as these actions are permenent
-- First, checking which column(s) are deemed unnecessary

select * from Nashville_Housing

-- Now, we will drop OwnerAddress, PropertyAddress, TaxDistrict, and SaleDate

alter table Nashville_Housing
drop column OwnerAddress, PropertyAddress, TaxDistrict, SaleDate
 
 -- Again, manual checking with the 'select*from table'
 -- Now, the whole point of data cleaning is to make the necessary changes, adjustments, trimmings, etc to make the data more usable for future analysis or maybe even machine learning purposes
 -- But in doing so, we have to be careful in the process to not mess up or worse, lose the raw data. So, it is up to us or the team to handle this task properly, and responsibly

 -- Thank you for reading, wish you well!

