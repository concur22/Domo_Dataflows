![Starvision Monthly Newsletter Banner](images/starvision-banner.png)




# Centralized Data Model


## Overview

This repository supports financial planning and analysis holistically, including datasets specific but not limited to: 

- Sales performance relative to:
	- Opportunity
 	- Product
 	- Customer
- Revenue Operations
- Income Statement Transactions
- Aged Accounts Receivables

---

/
├── data/           # Raw or sample data files
├── src/            # Source code (scripts, notebooks, functions)
├── docs/           # Documentation, guides, and tutorials
├── tests/          # Automated tests
├── README.md       # This file
└── ...             # Other relevant files/folders


# Domo Admin Tasks & Projects

---

## I. General Administrative Tasks

1. **Employ AI to generate precise meeting notes**
   
   - Particularly during discussions with Edward.
   - Leverage Domo’s AI chat box for advice:
     - Tracking Customer Health Scores over time
     - Data warehouse governance, Schema management/maintenance
     - Dashboard recommendations based on the task set that’s feeding each dashboard

2. **Conduct thorough research on business tools utilizing Grok/AI.**

3. **Develop Domo Newsletter**
   
   - Consider incorporating various videos (excluding any financial or sensitive data).

4. **Optimize datasets**
   
   - Implementation of hash keys
   - Dataset partitioning
   - Creation of indexes

5. **Deploy a Python script for dataset cleaning (with metadata output table)**
   
   - Establish a table/dataset to systematically identify:
     1. Columns
     2. Beast Modes
     3. Variables
     4. Cards
     5. Data Sets / Data Flows—archive originals in GitHub repository
     6. Dashboards
   - Target removal of elements that:
     - Remain unused or underutilized
     - Contain predominantly null values
     - Closely mirror other high-value columns
     - Exhibit minimal traffic based on card viewership
   - Enforce column standardization—reference Opportunities with Products:
     - Ensure uniform names across diverse datasets and versions
     - Identify columns with differing names yet producing identical categories/measures
     - Scrutinize columns sharing value types (e.g., date, numeric, categorical) despite name variations
   - Introduce prefixes (e.g., Opportunity, Product, Solution) to column naming conventions
   - Organize datasets: date columns first, then sub-dimension groups, sub-fact groups, and appendix for ad-hoc elements

6. **Construct a user group mapping table (anchored on Entity)**
   
   - Leverage Governance Toolkit for:
     - Group Management / User Management (from Bamboo and Entity/Department)
     - Implement PDP Automation for Domo user governance and automated PDP protocols

7. **Establish a repository mechanism**
   
   - Ensure every query modification automatically uploads to GitHub

8. **Investigate subscription options for Hex and/or alternative data warehousing tools**
   
   - Evaluate Domo Workbench as a potential solution

9. **Compute Z-Scores/Composite Scores**
   
   - For advanced benchmarking on:
     - One Page Plan
     - P&C Scorecard

---

## II. Functional Income Statement Dashboard

1. **Integrate comprehensive logic and notes within the Summary section**

2. **Incorporate Actuals “Compare To” Variable with options**
   
   - Budget, Annual, Quarterly, Trailing 3-Month Average, Monthly

3. **Implement fixed start and end date filter variables (relative date configuration)**
   
   - End Date: `LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH))`
   - Start Date: _[To be specified]_

4. **Include a display link to the data dictionary**

---

## III. Functional Income Statement Queries/Datasets

1. **Functional Income Statement with Cross Join**
   
   - Embed detailed logic and notes in the Summary SQL Query Template

2. **Apply:**
   
   - Updated functional income statement mapping logic
   - Budget amounts

3. **Deploy to the dashboard, deprecating the original Functional Income Statement dataset**
   
   - Archive the original in GitHub repository

4. **Commit all changes to the repository**

5. **Transfer existing PDP rules**

6. **Migrate the data dictionary**
   
   - Generate a new table or webform

7. **Reduce granularity from Customer level to partitions solely based on:**
   
   - "Entity"
   - "1-Account Group"
   - "4-Account Department"
   - "Account Number"

8. **Document the applied logic:**
   
   - **Option 1:** Filter transactions with post dates outside the Fiscal Year—exclude transactions beyond FY boundaries or >= current month
   - **Option 2 (chosen):**  
     - Include all NetSuite transactions codified under a Fiscal Year, correct post months to FY Start & End Months for consistency (12-month uniformity)
     - Adjust Post Month display to cap at FY boundaries; exclude adjusted “Post Month”s >= current month

   - **Cross join with date dimension**
     - Generate all conceivable dimensional combinations per post month, even if no transaction occurred
     - Enforces consistency in period-over-period calculations and avoids missing months due to no source data

