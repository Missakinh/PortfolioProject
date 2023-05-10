--SELECT*
--FROM PortfolioProject..CovidDeaths1csv 
--WHERE Continent is not null
--order by 4,5
--SELECT*
--FROM PortfolioProject..CovidVaccinations1csv 
--order by 4,5

--ALTER TABLE CovidVaccinations1csv
--ALTER COLUMN new_vaccinations float;
--GO
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM PortfolioProject..CovidDeaths1csv as dth
order by 1,2
--DeathPercentage (likelihood of dieing from covid in your country)
SELECT location, date, total_cases, total_deaths, (total_deaths*100/total_cases)  as DeathPercentage
FROM PortfolioProject..CovidDeaths1csv as dth
WHERE location LIKE '%states%'
order by 1,2

--ContractionPercentage (Likelihood of contracting Covid in your country)
SELECT location, date, population, total_cases, cast((total_cases *100/population) as float )  as ContractionPercentage
FROM PortfolioProject..CovidDeaths1csv as dth
WHERE location like '%states%'
order by 1,2

--Countries with the highest contraction rate
SELECT Location,Population, MAX(total_cases) as HighestCasesperlocation,cast(MAX((total_cases)*100/population) as float) as HighestContractionPercentage
FROM PortfolioProject..CovidDeaths1csv
GROUP BY Location, Population
ORDER BY HighestContractionPercentage desc

-- Countries with the highest death rate
SELECT Location,Population, MAX(total_cases) HighestCasesperloc, MAX(total_deaths) HighestDthperlocation,MAX(total_deaths*100)/MAX(total_cases) HighestDeathPercentage
FROM PortfolioProject..CovidDeaths1csv
WHERE Continent is not null
GROUP BY Location, population
ORDER BY HighestDeathPercentage desc

--HighestDeathCount per country 
SELECT Location, MAX(total_deaths) TotalDthperlocation
FROM PortfolioProject..CovidDeaths1csv
WHERE continent is not null
GROUP BY Location
ORDER BY TotalDthperlocation desc

--LOOKING AT CONTINENT
--Showing continents with the highest death count per population
SELECT continent,location, population, MAX(total_deaths) MaxDeathPerCountry
FROM PortfolioProject..CovidDeaths1csv
WHERE continent is not null
GROUP BY continent,location, population
ORDER BY MaxDeathPerCountry  desc

DROP TABLE IF EXISTS #ContPopDeath
 CREATE TABLE #ContPopDeath
 ( Continent nvarchar(255),
 Location nvarchar(255),
 Population numeric,
 MaxDeathPerCountry numeric
 )
 INSERT INTO #ContPopDeath
 SELECT continent,location, population, MAX(total_deaths) MaxDeathPerCountry
FROM PortfolioProject..CovidDeaths1csv
WHERE continent is not null
GROUP BY continent,location, population
ORDER BY MaxDeathPerCountry  desc

SELECT Continent,Location,Population,  SUM(Population) OVER(PARTITION BY Continent order by location) RollingContinentPop,
MaxDeathPerCountry,SUM(MaxDeathPerCountry) OVER(PARTITION BY Continent order by location) RollingContinentDeathCount
FROM #ContPopDeath
--ORDER BY RollingContinentPop desc

--2nd Temp Table
DROP TABLE IF EXISTS #ContPopDeath2
 CREATE TABLE #ContPopDeath2
 ( Continent nvarchar(255),
 Location nvarchar(255),
 RollingPopulation numeric,
 RollingDeathCount numeric
 )
 INSERT INTO #ContPopDeath2 
 SELECT Continent,Location, SUM(Population) OVER(PARTITION BY Continent order by location) RollingContinentPop,
SUM(MaxDeathPerCountry) OVER(PARTITION BY Continent order by location) RollingContinentDeathCount
FROM #ContPopDeath

SELECT Continent, MAX(RollingPopulation) TotalPopulation, MAX(RollingDeathCount) TotalDeathCount
FROM #ContPopDeath2 
GROUP BY Continent 
ORDER BY TotalDeathCount desc


--Global numbers
SELECT date,sum(new_cases) TotalCases, SUM(new_deaths) TotalDeaths, cast((SUM(new_deaths)*100/sum(new_cases))as float)  as DeathPercentage
FROM PortfolioProject..CovidDeaths1csv as dth
--WHERE location LIKE '%states%'
WHERE continent is not null
GROUP BY date
order by 1,2
--SELECT date,  total_cases, new_cases, total_deaths
--FROM PortfolioProject..CovidDeaths1csv as dth
--order by 1

--No of people vaccinated VS Total population       --partion by; so it sums the vaccinations per couuntry
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(vac.new_vaccinations) OVER(PARTITION BY dea.location) as TotalVacPerCountry
FROM PortfolioProject..CovidDeaths1csv dea
Join PortfolioProject..CovidVaccinations1csv vac
ON dea.location=vac.location
and dea.date=vac.date
WHERE dea.continent is not null
order by 2,3

--if we want to do the same thing but partion by date (rolling count of vaccinations)
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(vac.new_vaccinations) OVER(PARTITION BY dea.location ORDER BY dea.location,dea.date ) as RollingVacPerCountry
FROM PortfolioProject..CovidDeaths1csv dea
Join PortfolioProject..CovidVaccinations1csv vac
ON dea.location=vac.location
and dea.date=vac.date
WHERE dea.continent is not null
order by 2,3


--comparing people vaccinated with country population
--Using CTE (PeopleVacc VS Population)
--I tried to use CTE, then form a temp table from the CTE
WITH CTE_PopVsVacc as
( 
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(vac.new_vaccinations) OVER(PARTITION BY dea.location ORDER BY dea.location,dea.date) as RollingVacPerCountry
FROM PortfolioProject..CovidDeaths1csv dea
Join PortfolioProject..CovidVaccinations1csv vac
ON dea.location=vac.location
and dea.date=vac.date
WHERE dea.continent is not null )
--order by 2,3 )
SELECT continent,location, population, Max(RollingVacPerCountry) TotalPeopleVaccinated
FROM CTE_PopVsVacc
GROUP BY continent,location,population 
ORDER BY 2,3

--using Temp tables to calculate the PercentageVaccinatedPerCountry
DROP TABLE IF EXISTS #PercentageVaccinatedPerCountry
CREATE TABLE #PercentageVaccinatedPerCountry
( Continent nvarchar(255),
Location nvarchar(255),
Population numeric,
TotalPeoplevaccinated numeric )
INSERT INTO #PercentageVaccinatedPerCountry
 WITH CTE_PopVsVacc as
( 
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(vac.new_vaccinations) OVER(PARTITION BY dea.location ORDER BY dea.location,dea.date) as RollingVacPerCountry
FROM PortfolioProject..CovidDeaths1csv dea
Join PortfolioProject..CovidVaccinations1csv vac
ON dea.location=vac.location
and dea.date=vac.date
WHERE dea.continent is not null )
--order by 2,3 )
SELECT continent,location, population, Max(RollingVacPerCountry) TotalPeopleVaccinated 
FROM CTE_PopVsVacc
GROUP BY continent,location,population 
ORDER BY TotalPeopleVaccinated
--Didn't work

--So I first created a TEMP table, then created a CTE from it
DROP TABLE IF EXISTS #TotalPeopleVaccinatedPerCountry
CREATE TABLE #TotalPeopleVaccinatedPerCountry
( Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
Vaccinations numeric,
RollingVacPerCountry numeric )
INSERT INTO #TotalPeopleVaccinatedPerCountry
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(vac.new_vaccinations) OVER(PARTITION BY dea.location ORDER BY dea.location,dea.date) as RollingVacPerCountry
FROM PortfolioProject..CovidDeaths1csv dea
Join PortfolioProject..CovidVaccinations1csv vac
ON dea.location=vac.location
and dea.date=vac.date
WHERE dea.continent is not null
--WHERE  dea.location='Gibraltar' 
order by 2,3
SELECT Continent, Location, Population, MAX(RollingVacPerCountry) TotalPeoplevaccinated
FROM #TotalPeopleVaccinatedPerCountry
GROUP BY Continent, Location, Population
ORDER BY TotalPeoplevaccinated desc

WITH CTE_PercentageVaccPerCountry as
(SELECT Continent, Location, Population, MAX(RollingVacPerCountry) TotalPeoplevaccinated
FROM #TotalPeopleVaccinatedPerCountry
GROUP BY Continent, Location, Population
--ORDER BY TotalPeoplevaccinated desc
)
SELECT *, (TotalPeoplevaccinated*100/Population) PercentageVaccinatedPerCountry
FROM CTE_PercentageVaccPerCountry
ORDER BY PercentageVaccinatedPerCountry desc
--And it worked!

--Creating Views (to store data for visualizations)

CREATE VIEW PopVSVac as
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(vac.new_vaccinations) OVER(PARTITION BY dea.location ORDER BY dea.location,dea.date) as RollingVacPerCountry
FROM PortfolioProject..CovidDeaths1csv dea
Join PortfolioProject..CovidVaccinations1csv vac
ON dea.location=vac.location
and dea.date=vac.date
WHERE  dea.continent is not null
--order by 2,3 
                                    
CREATE VIEW DeathCountPerCountry as
SELECT Location, MAX(total_deaths) TotalDthperlocation
FROM PortfolioProject..CovidDeaths1csv
WHERE continent is not null
GROUP BY Location
--ORDER BY TotalDthperlocation desc
                                              
  --(I think Temporary tables cannot be put into views)
  