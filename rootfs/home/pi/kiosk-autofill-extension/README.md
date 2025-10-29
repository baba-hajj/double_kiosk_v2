# Kiosk Password Autofill Extension

A simple Chrome extension to automatically fill the password field on the kiosk login page.

## What It Does

- Automatically fills the password field with "iheartjane" when the page loads
- Works on `https://kiosk.iheartjane.com/*` domain
- Retries up to 10 times if the password field isn't immediately available
- Uses MutationObserver to detect dynamically loaded content
- Logs activity to browser console for debugging

## Files

- `manifest.json` - Extension configuration (Manifest V3)
- `autofill.js` - Main autofill logic
- `README.md` - This file

## How It Works

1. Extension runs when page matches `https://kiosk.iheartjane.com/*`
2. Waits for DOM to be ready
3. Searches for password field with ID `#password`
4. Fills field with password "iheartjane"
5. Dispatches input/change events to trigger any form validation
6. Optionally can auto-submit form (currently disabled)

## Installation

This extension is automatically loaded by Chromium via the `--load-extension` flag in the startup script.

```bash
chromium --load-extension=/home/pi/kiosk-autofill-extension ...
```

## Customization

### Change Password

Edit `autofill.js` and change the `PASSWORD` constant:

```javascript
const PASSWORD = 'your-password-here';
```

### Enable Auto-Submit

Uncomment the auto-submit code in `autofill.js`:

```javascript
// Uncomment these lines to enable auto-submit:
/*
setTimeout(() => {
  const form = passwordField.closest('form');
  if (form) {
    log('Submitting form...');
    form.submit();
  }
}, 500);
*/
```

### Adjust Retry Settings

Modify these constants in `autofill.js`:

```javascript
const MAX_ATTEMPTS = 10;        // Number of retry attempts
const RETRY_DELAY = 500;        // Delay between attempts (ms)
```

## Debugging

Open Chrome DevTools (if accessible) and check the Console tab. You'll see messages like:

```
[Kiosk Autofill] Page already loaded, starting autofill...
[Kiosk Autofill] Attempt 1/10 to find password field...
[Kiosk Autofill] Password field filled successfully
```

## Security Note

**Important**: This extension stores the password in plaintext in the JavaScript file. This is acceptable for:
- Public kiosk systems
- Non-sensitive passwords
- Isolated/controlled environments

For sensitive passwords or production systems, consider using Chromium's native password manager instead.

## Troubleshooting

### Password field not filling

1. Check console for error messages
2. Verify the password field ID is still `#password`
3. Increase `MAX_ATTEMPTS` or `RETRY_DELAY`
4. Check if the site structure has changed

### Extension not loading

1. Verify extension path in Chromium launch command
2. Check extension files are in `/home/pi/kiosk-autofill-extension/`
3. Look for extension errors in Chrome's extension page (chrome://extensions/)

## Version History

- **1.0.0** (2025-10-29) - Initial release
  - Auto-fill password field
  - Retry mechanism
  - MutationObserver for dynamic content
  - Console logging
