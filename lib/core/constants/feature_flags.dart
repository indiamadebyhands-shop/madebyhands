/// Switches Google sign-in on or off for the whole app. While `false` the
/// welcome screen shows a short notice instead of the "Continue with Google"
/// button (the Terms and Privacy Policy links stay visible). Set to `true`
/// and redeploy to bring sign-in back.
const bool kGoogleSignInEnabled = true;

/// TEMPORARY, for the payment gateway's review of the site. While `true` the
/// welcome screen shows a "Continue as test buyer" button that skips Google
/// sign-in and role selection: it signs the visitor in as a brand-new guest
/// buyer (Firebase anonymous sign-in), so they can browse, check out and
/// track orders like any buyer but see nobody else's data.
///
/// It needs the Anonymous provider enabled in Firebase Authentication. To
/// remove it after the review: set this to `false`, redeploy, turn the
/// Anonymous provider off again, and delete the guest accounts (their user
/// documents carry `isTestAccount: true`).
const bool kTestBuyerLoginEnabled = true;
