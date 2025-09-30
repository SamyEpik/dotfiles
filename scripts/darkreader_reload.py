#!/usr/bin/env python3
import os
import time
from selenium.webdriver.firefox.options import Options
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC


PROFILE = os.path.expanduser("/home/samuel/.mozilla/firefox/gwwymseg.default-release")
UUID = "a5dc5e06-cffd-4405-9ec4-3fbdeaa7ba56"
THEME_JSON_PATH = os.path.expanduser("/home/samuel/.cache/wal/darkreader.json")


def import_darkreader_settings(driver, wait_seconds=20):
    wait = WebDriverWait(driver, wait_seconds)

    # Ensure we're on the Dark Reader options page
    if not driver.current_url.startswith("moz-extension://"):
        print("Opening Dark Reader options…")
        driver.get(f"moz-extension://{UUID}/ui/options/index.html")

    # 1) Go to the "Advanced" section
    try:
        # Preferred: the button that contains the "settings-icon-advanced" icon
        adv_btn = wait.until(
            EC.element_to_be_clickable(
                (
                    By.XPATH,
                    "//*[contains(@class,'settings-icon-advanced')]/ancestor::button[1]",
                )
            )
        )
    except Exception:
        # Fallback: button containing the text "Advanced"
        adv_btn = wait.until(
            EC.element_to_be_clickable((By.XPATH, "//button[contains(., 'Advanced')]"))
        )
    print("Clicking Advanced…")
    adv_btn.click()
    print("Advanced opened.")

    # 2) Click "Import settings"
    import_btn = wait.until(
        EC.element_to_be_clickable((By.CLASS_NAME, "advanced__import-settings-button"))
    )

    print("Clicking Import settings…")
    import_btn.click()

    # 3) Confirm the message box (OK)
    ok_btn = wait.until(
        EC.element_to_be_clickable((By.CLASS_NAME, "message-box__button-ok"))
    )
    print("Confirming import dialog…")
    ok_btn.click()

    # 4) The hidden file input is injected only after confirming.
    #    Grab it, make it visible (so geckodriver is happy), then send the path.
    file_input = wait.until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, "input[type='file'][accept$='.json']")
        )
    )

    # Some geckodriver builds require the element to be interactable; unhide it:
    driver.execute_script(
        "arguments[0].style.display='block'; arguments[0].removeAttribute('hidden');",
        file_input,
    )

    print("Uploading JSON file…")
    file_input.send_keys(THEME_JSON_PATH)

    # Optional: small settle wait or add a post-condition if you want to verify apply success.
    # wait.until(...)  # e.g., check some setting visibly changed on the page
    print("Done!")
    time.sleep(1)


def main():
    opts = Options()
    opts.add_argument("-profile")
    opts.add_argument(PROFILE)

    driver = webdriver.Firefox(options=opts)
    try:
        import_darkreader_settings(driver)
    finally:
        driver.quit()


if __name__ == "__main__":
    main()
