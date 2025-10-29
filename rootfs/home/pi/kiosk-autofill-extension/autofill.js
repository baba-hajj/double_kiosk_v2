// Kiosk Password Autofill Script
// Automatically fills password field with "iheartjane" on page load

(function() {
  'use strict';

  // Configuration
  const PASSWORD = 'iheartjane';
  const MAX_ATTEMPTS = 10;
  const RETRY_DELAY = 500; // ms

  // Log function for debugging
  function log(message) {
    console.log('[Kiosk Autofill]', message);
  }

  // Function to fill password field
  function fillPassword(attempt = 1) {
    log(`Attempt ${attempt}/${MAX_ATTEMPTS} to find password field...`);

    // Find password field by ID
    const passwordField = document.querySelector('#password');

    if (passwordField) {
      // Check if field is already filled
      if (passwordField.value) {
        log('Password field already has a value, skipping autofill');
        return true;
      }

      // Fill the password
      passwordField.value = PASSWORD;
      log('Password field filled successfully');

      // Dispatch events to trigger any listeners
      passwordField.dispatchEvent(new Event('input', { bubbles: true }));
      passwordField.dispatchEvent(new Event('change', { bubbles: true }));

      // Optional: Auto-submit form after a delay
      // Uncomment the following if you want automatic form submission
      /*
      setTimeout(() => {
        const form = passwordField.closest('form');
        if (form) {
          log('Submitting form...');
          form.submit();
        }
      }, 500);
      */

      return true;
    } else {
      log('Password field not found yet');

      // Retry if we haven't exceeded max attempts
      if (attempt < MAX_ATTEMPTS) {
        setTimeout(() => fillPassword(attempt + 1), RETRY_DELAY);
      } else {
        log('Max attempts reached, password field not found');
      }
      return false;
    }
  }

  // Wait for page to be fully loaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      log('DOM loaded, starting autofill...');
      fillPassword();
    });
  } else {
    log('Page already loaded, starting autofill...');
    fillPassword();
  }

  // Also observe for dynamic content changes
  const observer = new MutationObserver((mutations) => {
    const passwordField = document.querySelector('#password');
    if (passwordField && !passwordField.value) {
      log('Password field detected via mutation observer');
      observer.disconnect();
      fillPassword();
    }
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });

  // Stop observing after 10 seconds
  setTimeout(() => {
    observer.disconnect();
    log('Mutation observer stopped');
  }, 10000);

})();
