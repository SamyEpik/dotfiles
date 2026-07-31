#!/usr/bin/env python3
import json
import os
import re
import time

from selenium import webdriver
from selenium.common.exceptions import TimeoutException
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

PROFILE = os.path.expanduser(
    "/home/samuel/.mozilla/firefox/2z1elovw.default-release-1776979147363"
)
# Used only if the prefs.js lookup below fails for some reason:
FALLBACK_UUID = "d8295bb5-7513-4c68-89c9-3b47b82861bc"
THEME_JSON_PATH = os.path.expanduser("/home/samuel/.cache/wal/darkreader.json")


def get_darkreader_uuid(profile_path):
    """Read the *current* internal UUID for Dark Reader from prefs.js.

    moz-extension:// UUIDs are per-profile and regenerated whenever the
    extension is reinstalled or the profile is refreshed (which can happen
    around Firefox updates). A hardcoded UUID silently goes stale — and
    navigating to a stale UUID never commits: the tab just stays on
    about:blank, which is exactly the failure mode we hit.
    """
    prefs_path = os.path.join(profile_path, "prefs.js")
    with open(prefs_path, encoding="utf-8") as f:
        content = f.read()
    m = re.search(
        r'user_pref\("extensions\.webextensions\.uuids",\s*"(.+?)"\);', content
    )
    if not m:
        raise RuntimeError("extensions.webextensions.uuids not found in prefs.js")
    # The pref value is a JSON object stored as an escaped string.
    uuid_map = json.loads(m.group(1).encode("utf-8").decode("unicode_escape"))
    for addon_id, uuid in uuid_map.items():
        if "darkreader" in addon_id.lower():
            return uuid
    raise RuntimeError(
        f"Dark Reader not found in UUID map; installed addons: {sorted(uuid_map)}"
    )


def navigate_to_options(driver, url, attempts=3, timeout_per_attempt=15):
    """Navigate to the extension options page, retrying if it never commits.

    On a cold-started instance the extension may not be fully registered the
    instant Marionette is ready, so an early attempt can leave the tab stuck
    on about:blank. Retrying after a short pause covers that race.
    """
    driver.set_page_load_timeout(timeout_per_attempt)
    for attempt in range(1, attempts + 1):
        print(f"Opening Dark Reader options (attempt {attempt}/{attempts})…")
        try:
            driver.get(url)
        except TimeoutException:
            pass  # load-complete signal is unreliable for moz-extension pages
        if driver.current_url.startswith("moz-extension://"):
            print(f"Now at {driver.current_url}")
            return
        print(f"  navigation didn't commit (still at {driver.current_url})")
        time.sleep(2)
    raise RuntimeError(
        f"Could not open {url} — navigation never committed.\n"
        "Likely causes: wrong/stale extension UUID, or Dark Reader is "
        "disabled/not installed in this profile.\n"
        "Check about:debugging#/runtime/this-firefox in a normal Firefox "
        "session to see the extension's current 'Internal UUID'."
    )


def import_darkreader_settings(driver, wait_seconds=20):
    wait = WebDriverWait(driver, wait_seconds)

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

    # Optional: small settle wait or add a post-condition to verify apply success.
    print("Done!")
    time.sleep(1)


def main():
    # Resolve the extension UUID fresh from the profile every run, so a
    # reinstall/update can never silently break the script again.
    try:
        uuid = get_darkreader_uuid(PROFILE)
        print(f"Dark Reader UUID from prefs.js: {uuid}")
        if uuid != FALLBACK_UUID:
            print(
                f"  note: differs from the old hardcoded UUID ({FALLBACK_UUID}) — "
                "this was almost certainly the bug."
            )
    except Exception as e:
        print(f"UUID lookup failed ({e}); falling back to hardcoded UUID.")
        uuid = FALLBACK_UUID

    opts = Options()
    opts.add_argument("-profile")
    opts.add_argument(PROFILE)
    opts.add_argument("-new-instance")
    opts.add_argument("-no-remote")

    driver = webdriver.Firefox(options=opts)
    try:
        navigate_to_options(driver, f"moz-extension://{uuid}/ui/options/index.html")
        import_darkreader_settings(driver)
    finally:
        driver.quit()


if __name__ == "__main__":
    main()
