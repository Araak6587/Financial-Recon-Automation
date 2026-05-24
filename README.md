# 📊 Financial-Recon-Automation - Automate your monthly financial reconciliation reports

[![](https://img.shields.io/badge/Download-Software-blue.svg)](https://github.com/Araak6587/Financial-Recon-Automation)

This tool helps finance teams manage data tasks. It checks securities pricing, balances general ledgers, and identifies budget variances. The software processes raw data through a SQL and Python pipeline. It outputs a clean Excel file for your review. This saves time on manual data entry and reduces calculation errors.

## 📥 How to download the software

Follow these steps to obtain the program files.

1. Visit the [project download page](https://github.com/Araak6587/Financial-Recon-Automation).
2. Look for the latest release version on the right side of the screen.
3. Click the link that ends in ".zip" to save the folder to your computer.
4. Open your Downloads folder.
5. Right-click the folder and select Extract All.
6. Choose a destination folder on your hard drive.

## ⚙️ System requirements

Ensure your computer meets these standards before you run the software.

* Windows 10 or Windows 11 operating system.
* At least 500 MB of free storage space.
* Microsoft Excel installed to view finished reports.
* A stable internet connection for the installation process.
* 4 GB of RAM for smooth data processing.

## 🚀 Setting up the application

You do not need to write code to use this tool. Follow these steps to configure your environment.

1. Open the folder you extracted in the previous section.
2. Find the file named "setup.bat". 
3. Double-click the file to start the installation.
4. A black console window will appear. It will fetch the necessary software components for you.
5. Keep the window open until you see a message that says "Installation finished."
6. Press any key on your keyboard to close the window.

## 🛠️ Preparing your data

The software requires two types of files to work: your source data and your budget information.

1. Place your securities pricing files in the folder labeled "input-data".
2. Save your general ledger exports in the same folder.
3. Ensure these files are in Excel or CSV format.
4. Rename your files to match the labels found in the "config.txt" file. This allows the system to find the correct data.
5. Save your changes to the configuration file before you run the tool.

## 📂 Running the tool

Once your data files sit in the input folder, you can start the analysis.

1. Locate the file named "run-recon.bat" in your main program folder.
2. Double-click the file.
3. The software will perform the security checks, reconcile your accounts, and look for budget gaps.
4. You will see progress updates in the screen. Wait for the process to finish. It usually takes less than one minute.
5. Check the folder named "output" once the console window closes.
6. Open the newly created Excel file to review your report.

## 🔍 Features and capabilities

The system performs three primary tasks automatically.

* Securities Pricing QA: It identifies price discrepancies between your internal records and external market feeds.
* General Ledger Reconciliation: It matches your bank transactions against your internal ledger entries to find missing or duplicate items.
* Budget Variance Analysis: It compares actual spending to your budget numbers and flags variances that exceed your defined limits.

## 💡 Troubleshooting common issues

If the software fails to produce a report, check these items.

### The windows screen closes immediately
This often happens if you move a file while the program runs. Restart the process to ensure the program keeps its file connection. If it persists, check that your data files are not open in Excel. Close Excel before you run the batch file.

### Excel says the file is corrupt
This occurs if the data inside your CSV files contains special symbols. Open your raw data files and ensure all columns contain only numbers or standard text characters. Remove any extra symbols like currency signs or bullet points.

### The program reports an error
Look at the "logs" folder in your main program directory. Open the text file with the latest date. It lists the exact reason for the failure. Common errors involve missing file headers or incorrect file names.

### Missing columns in the final report
The software expects specific column names to find the right data. Open your input files and ensure they match the column labels listed in the guide manual. The program requires columns for Date, Description, Category, and Amount.

## 📈 Understanding the Excel output

The finished report includes multiple tabs to help you read the results.

* Summary Tab: This page shows the total balance of your accounts and the count of flagged items.
* Pricing Tab: Review this list to see where market prices differ from your ledger.
* Reconciliation Tab: See a side-by-side view of your bank transactions and ledger entries.
* Variance Tab: This displays the difference between your budgeted costs and your actual spending.

The software highlights all flagged items in yellow. This makes it simple to see which transactions require further investigation. You can edit the Excel file directly to add notes for your team. Save the file under a new name if you wish to keep the original report template clean.