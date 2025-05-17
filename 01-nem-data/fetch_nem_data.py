#!/usr/bin/env python3
import os
import time
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager

# 0. Make all paths relative to this script’s folder
os.chdir(os.path.dirname(os.path.abspath(__file__)))

def wait_for_new_file(folder, before, timeout=60):
    """
    Wait until a new .csv appears in `folder` that wasn't in `before`.
    Returns the new filename.
    """
    elapsed = 0
    while elapsed < timeout:
        now = set(os.listdir(folder))
        new = [f for f in now - before if f.lower().endswith(".csv")]
        if new:
            return new[0]
        time.sleep(1)
        elapsed += 1
    raise RuntimeError(f"No new CSV appeared in {folder!r} within {timeout} seconds")

def download_region_csv(region, url, download_dir):
    """
    Spins up a fresh Chrome instance, navigates to `url`, clicks the export button,
    waits for the newly‐downloaded CSV, and then quits Chrome.
    """
    # take snapshot of files before download
    before = set(os.listdir(download_dir))

    # set Chrome to download without prompt
    chrome_options = webdriver.ChromeOptions()
    prefs = {
        "download.default_directory": download_dir,
        "download.prompt_for_download": False,
        "download.directory_upgrade": True,
        "safebrowsing.enabled": True,
        # optionally disable images/stylesheets to speed up:
        "profile.managed_default_content_settings.images": 2,
        "profile.managed_default_content_settings.stylesheets": 2,
    }
    chrome_options.add_experimental_option("prefs", prefs)
    # chrome_options.add_argument("--headless=new")  # headless may need extra flags for downloads

    driver = webdriver.Chrome(
        service=Service(ChromeDriverManager().install()),
        options=chrome_options
    )
    wait = WebDriverWait(driver, 20)

    try:
        print(f"  → Navigating to {region} URL")
        driver.get(url)

        # wait for and click the export button
        export_div = wait.until(EC.element_to_be_clickable(
            (By.CSS_SELECTOR, "div[id^='export_']")))
        export_div.click()

        # wait for the new CSV to land
        new_file = wait_for_new_file(download_dir, before, timeout=60)
        print(f"  → {region} download complete: {new_file}")

    finally:
        driver.quit()

def download_all_regions():
    download_dir = os.path.join(os.getcwd(), "01-nem-data")
    os.makedirs(download_dir, exist_ok=True)
    print("Download directory is:", os.path.abspath(download_dir))

    region_urls = {
        "nem":  "https://explore.openelectricity.org.au/energy/nem/?range=all&interval=1M&view=discrete-time&group=Detailed",
        "nsw1": "https://explore.openelectricity.org.au/energy/nsw1/?range=all&interval=1M&view=discrete-time&group=Detailed",
        "qld1": "https://explore.openelectricity.org.au/energy/qld1/?range=all&interval=1M&view=discrete-time&group=Detailed",
        "sa1":  "https://explore.openelectricity.org.au/energy/sa1/?range=all&interval=1M&view=discrete-time&group=Detailed",
        "tas1": "https://explore.openelectricity.org.au/energy/tas1/?range=all&interval=1M&view=discrete-time&group=Detailed",
        "vic1": "https://explore.openelectricity.org.au/energy/vic1/?range=all&interval=1M&view=discrete-time&group=Detailed",
        "wem":  "https://explore.openelectricity.org.au/energy/wem/?range=all&interval=1M&view=discrete-time&group=Detailed",
    }

    for region, url in region_urls.items():
        print(f"Fetching region '{region}'...")
        download_region_csv(region, url, download_dir)
        # brief pause to avoid hammering the site
        time.sleep(1)

if __name__ == "__main__":
    download_all_regions()