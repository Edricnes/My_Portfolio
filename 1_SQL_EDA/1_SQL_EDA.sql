-- Hello! Thank you for checking my first portfolio
-- Please keep in mind I want to showcase various querying features I know of, so these queries may not exactly the most efficient in terms of EDA
-- With limited free time I still have, this is what I have in store, so open up SQL_EDA_pdf listed on my web and let's go!

-- Dataset used: https://ourworldindata.org/covid-deaths (accumulating data updated monthly, taken in August 2022)

--The data we're using are the global COVID-19 Deaths and Vaccinations, and we'll do some data exploration on it

-- 1. After loading up the data on the local database, let's see what the data has to offer
-- Looking at all the different variables of the raw data will give us an idea what we're working with
select * from COVID_Deaths (Pic 1)

-- 2. Let's select the maximum mortality rate at any given date in each country
select location, max((total_deaths/total_cases)*100) as Mortality_Percentage
from COVID_Deaths
group by location (Pic 2)

-- 3. How about the mortality rate nowadays?
-- For this specific task we know that the latest date from the data is 2022-09-08
select location, date, ((total_deaths/total_cases)*100) as Mortality_Percentage
from COVID_Deaths
where date in (select max(date) from COVID_Deaths)
order by 1 (Pic 3)

-- 4. Let's dive into how Indonesia is doing compared to its neighbouring countries (say Malaysia and Singapore)
-- To make our lifes easier, let's find Asian countries' iso_code and save it as a procedure
create procedure asia_iso as
select distinct iso_code, location from COVID_Deaths
where continent = 'Asia'(Pic 4.1)
-- Whenever we need to dwell in data of a specific Asian country (or some), we'll only need to execute this to look up the relevant iso should the occasion arises
-- For location querying purposes, the iso_code is much more preferred because there may be some inconsistencies with the location data, be it ->
-- too many letters (which can be a hassle) or even extra unwanted spaces in the location data, which has yet to be cleaned.

-- Let's try using asia_iso procedure to find the iso_code of Malaysia, Singapore, and Indonesia:
exec asia_iso (Pic 4.2)

-- Now we've obtained the iso_code : IDN, SGP, MYS
select location, date, ((total_deaths/total_cases)*100) as Mortality_Percentage
from COVID_Deaths
where date in (select max(date) from COVID_Deaths) and (iso_code = 'IDN' or iso_code = 'SGP' or iso_code = 'MYS')
order by 3 (Pic 4.3)
-- Shocking (but not really), we have the highest mortality rate of the COVID outbreak compared to our neigbours

-- 5. Now let's find out which countries have the highest infected rates, and see where Indonesia stacks up
select location, population, max(total_cases) as infection_to_date,
	max((total_cases/population))*100 as infected_rate_population
from COVID_Deaths
group by location, population
order by infected_rate_population desc (Pic 5)
-- Gee whiz, 65% of the Faeroe Islands' population have been infected
-- Scrolling through we can see that Indonesia is at the 164th place at 2.33%, out of the 228 countries
-- Higher or lower infected rate can be both good or bad, depending on how well each country's approach in handling COVID is

-- 6. Let's look at the total deaths by each country
select location, max(total_deaths) as death_count
from COVID_Deaths
group by location
order by death_count desc (Pic 6.1)
-- If we run the script above the death_count values seem really odd, not really descendingly ordered

-- To fix that, we have to add specific instruction so the query takes the data as integers
select location, max(cast(total_deaths as int)) as death_count
from COVID_Deaths
group by location
order by death_count desc (Pic 6.2)

-- Lovely, but then you could see that not only countries that are in it
-- The data as it turned out, have grouped some of the data together based on continents and even income levels
-- Just to make sure, let's verify that our continent based filtering is valid by running the next query
select distinct location
from COVID_Deaths
where continent is not null (Pic 6.3)
-- A brief manual observation confirms that the result output contains only countries' names, just what we need exactly
-- Of course, Pic 6.3 won't have all the 231 rows of country names as it is too long, but you get the idea

-- Now these extra groups don't have values in the continent column, so let's use this knowledge for our filtering purposes
select location, max(cast(total_deaths as int)) as death_count
from COVID_Deaths
where continent is not null
group by location
order by death_count desc (Pic 6.4)
-- The United States has the highest death count, that's in sync with COVID news over the past couple years if you keep track of it
-- And Indonesia's death count is at 9th place, not a good news exactly

-- 7. Let's add in population factor to the previous query
select location, population, max(cast(total_deaths as int)) as death_count,
	   (max(cast(total_deaths as int))/population)*100 as death_rate_to_population
from COVID_Deaths
where continent is not null
group by location, population
order by death_rate_to_population desc (Pic 7)

-- 8. Now let's try breaking our queries by the order of time
select date, sum(new_cases) as total_cases, sum(cast(new_deaths as int)) as total_deaths,
	   sum(cast(new_deaths as int))/sum(new_cases)*100 as death_percentage
from COVID_Deaths
where continent is not null
group by date
order by 1,2 (Pic 8)
-- It should be noted that total_cases and total_deaths values are not a sum over time, so there are ups and downs
-- The sum function strictly adds values based on the exact same date

-- 9. In addition, let's look at population and vaccinations
select dead.continent, dead.location, dead.date, dead.population, vacc.new_vaccinations
from COVID_Deaths dead
join COVID_Vaccinations vacc
	on dead.location = vacc.location and
	dead.date = vacc.date
where dead.continent is not null
order by 2,3 (Pic 9)

-- 10. That is good and all, but it is still messy and let's try to look at the total vaccination number over time
-- But first, let's determine the date when the first vaccination in the whole world was done
select location, min(date) from COVID_Vaccinations
where new_vaccinations is not null and date < '2021-01-01 00:00:00.000' and continent is not null
group by location
order by 2 (Pic 10.1)

-- So, we can see that the earliest date was '2020-12-09 00:00:00.000' by Norway
-- Let's use the date to help us filter the data of population and rolling vaccinations by each country
select dead.continent, dead.location, dead.date, dead.population, vacc.new_vaccinations,
		sum(cast(vacc.new_vaccinations as bigint)) over (partition by dead.location order by
		dead.location, dead.date) as total_vaccinations_over_time
from COVID_Deaths dead
join COVID_Vaccinations vacc
	on dead.location = vacc.location and
	dead.date = vacc.date
where dead.continent is not null and dead.date between '2020-12-09 00:00:00.000' and (select max(date) from COVID_Deaths)
order by 2, 3 (Pic 10.2)
-- Now we can see the historic number of people vaccinated daily in each country, with accumulated vaccinations

-- Some of you keen eyed readers may notice why we use bigint instead of int
-- 11. Of course I used int first, but instead got an error. Let's see the total sum of vaccinations
select sum(convert(bigint ,vacc.new_vaccinations)) as sum_of_vaccs
from COVID_Deaths dead
join COVID_Vaccinations vacc
	on dead.location = vacc.location and
	dead.date = vacc.date
where dead.continent is not null (Pic 11)
-- Turns out the total vaccinations worldwide has exceeded 2,147 billion (the hard limit), making the use of bigint necessary

-- 12. Now, I want to create a new column containing percentage of the population getting vaccinations
with Pops_vs_Vacc (Continent, Location, Date, Population, New_Vaccinations, Total_Vaccinations) as 
(
select dead.continent, dead.location, dead.date, dead.population, vacc.new_vaccinations,
		sum(cast(vacc.new_vaccinations as bigint)) over (partition by dead.location order by
		dead.location, dead.date) as total_vaccinations_over_time
from COVID_Deaths dead
join COVID_Vaccinations vacc
	on dead.location = vacc.location and
	dead.date = vacc.date
where dead.continent is not null and dead.date between '2020-12-09 00:00:00.000' and (select max(date) from COVID_Deaths)
)
select *, (Total_Vaccinations/Population)*100 as Vaccinations_Percentage
from Pops_vs_Vacc (Pic 12)
-- We used CTE or Common Table Experssion to create the calculation
-- Now, it should be noted that with CTEs, we need to run the whole query everytime

-- 13. Another way is to use temp tables, let's try that
drop table if exists #Vaccinated_Population_Percentage
create table #Vaccinated_Population_Percentage
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_Vaccinations numeric,
Total_Vaccinations numeric
) (Pic 13.1)

insert into #Vaccinated_Population_Percentage
select dead.continent, dead.location, dead.date, dead.population, vacc.new_vaccinations,
		sum(cast(vacc.new_vaccinations as bigint)) over (partition by dead.location order by
		dead.location, dead.date) as total_vaccinations_over_time
from COVID_Deaths dead
join COVID_Vaccinations vacc
	on dead.location = vacc.location and
	dead.date = vacc.date
where dead.continent is not null and dead.date between '2020-12-09 00:00:00.000' and (select max(date) from COVID_Deaths)
order by 2, 3 (Pic 13.2)

select *, (Total_Vaccinations/Population)*100 as Vaccinations_Percentage
from #Vaccinated_Population_Percentage (Pic 13.3)

-- Now we can independently execute the vacc-pops percentage with temp tables, notice that Pic 13.3 displays the same result as Pic 12
-- Or, we could execute other calculations that suit our needs with the available data from our temp table

-- Now, we want to prepare some data for basic data visualization purposes, which I'll do in the next one with Tableau
-- By running these queries and saving the ouput as Excel files, we can then import it into Tableau
-- Vis_1 (Q1.)
select sum(new_cases) as total_cases, sum(cast(new_deaths as int)) as total_deaths,
sum(cast(new_deaths as bigint))/sum(new_cases)*100 as Death_Percentage
from COVID_Deaths
where continent is not null
order by 1, 2

-- Vis_2 (Q2.)
select location, sum(cast(new_deaths as bigint)) as total_death_count
from COVID_Deaths
where continent is null
and location not in ('World', 'European Union', 'International') and location not like '%income'
group by location
order by total_death_count desc

-- Vis_3 (Q3.)
select location, population, max(total_cases) as max_infection_count, 
max((total_cases/population))*100 as percent_population_infected
from COVID_Deaths
group by location, population

-- Vis_4 (Q4.)
select location, population, date, max(total_cases) as max_infection_count, 
max((total_cases/population))*100 as percent_population_infected
from COVID_Deaths
group by location, population, date
order by 1, 3 desc
