# Domo_Dataflows

## Functional Income Statement with Cross Join
  * Apply:
  		* New set of functional income statement mapping logic
      * Budget amounts
  * Deploy to dashboard
	* Commit changes in Repo
  * Enact PDP rules
  * Transfer data dictionary
      * Create table/webform
  * Reduced it from Customer grain to partition based on only: 
      * "Entity"
      * "1-Account Group"
      * "4-Account Department",
      * "Account Number"
  * List out logic used:
      * Two Options (went with second option)
          * Case: Filter out transactions that have post dates outside of the Fiscal Year 
              * Excluding transactions from post month’s that are out of the FY period’s boundaries 
                  * And greater >= current month
          * Case: Include all transactions coming from NetSuite that have been codified under a given Fiscal Year, regardless of outlier post dates, and also correct those post months so that the outlier transactions are capped by the FY Start & End Months for clean visual trends and period comparison columns (adds layer of 12 month consistency).
              * Include transactions from all post month’s, regardless of whether the post date falls outside of the the fiscal year start/end
                  * And Adjusted Post Month display so that it will at minimum show the FY Start Month & at maximum show the lFY End Month
                  * Exclude “Post Month”’s (adjusted) that are greater or equal to current month
      * Cross join to date dimension to produce all possible dimensional outcomes for any given post month, regardless of if a particular transaction actually occurred or not
          * Also adds consistency for period over period column calculations, and avoids cases where the wrong month(s) are selected due to lack of actual transactions in the source data.  

## Functional Income Statement
  * Mostly correct, with the expection of period change columns/calcs
      * This is due to a lack of complete transaction activity for each dimensional attribute for every given month
          * So when partitioning and/or creating lag functions, you may skip some post months unintentionally if the actual transaction rows don't exist     

## Functional Income Statement with Budget
  * Needs a bit of work:
      * Try to use CTE's in Magic ETL SQL tile:
          * 1 - Cross Join with Functional Mapping (using new template logic)
          * 2 - Join actual amounts
          * 3 - Join budget amounts

name: Update README with Directory Tree

on: [push]

jobs:
  update-readme:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Install tree
        run: sudo apt-get update && sudo apt-get install -y tree

      - name: Generate directory tree
        run: tree -L 2 > tree.txt

      - name: Update README.md
        run: |
          # Remove old tree if it exists
          awk '/^## Project Structure$/ {exit} {print}' README.md > README.tmp
          mv README.tmp README.md
          # Append new tree
          echo -e "\n## Project Structure\n" >> README.md
          cat tree.txt >> README.md

      - name: Commit and push changes
        run: |
          git config --global user.name 'github-actions'
          git config --global user.email 'github-actions@github.com'
          git add README.md
          git commit -m "Update README with directory tree [automated]"
          git push
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
