---
stage: Secure
group: Dynamic Analysis
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
type: reference, howto
---

# Authentication (DAST) **(ULTIMATE)**

WARNING:
**Never** run an authenticated scan against a production server.
Authenticated scans may perform *any* function that the authenticated user can,
including modifying or deleting data, submitting forms, and following links.
Only run an authenticated scan against a test server.

Authentication logs a user in before a DAST scan so that the analyzer can test
as much of the application as possible when searching for vulnerabilities.

DAST uses a browser to authenticate the user so that the login form has the necessary JavaScript
and styling required to submit the form. DAST finds the username and password fields and fills them with their respective values.
The login form is submitted, and when the response returns, a series of checks verify if authentication was successful.
DAST saves the credentials for reuse when crawling the target application.

If DAST fails to authenticate, the scan halts and the CI job fails.

Authentication supports single-step login forms, multi-step login forms, single sign-on, and authenticating to URLs outside of the configured target URL.

## Getting started

NOTE:
We recommend periodically confirming that the analyzer's authentication is still working, as this tends to break over
time due to changes to the application.

To run a DAST authenticated scan:

- Read the [prerequisite](#prerequisites) conditions for authentication.
- [Update your target website](#update-the-target-website) to a landing page of an authenticated user. 
- If your login form has the username, password and submit button on a single page, use the [CI/CD variables](#available-cicd-variables) to configure [single-step](#configuration-for-a-single-step-login-form) login form authentication.
- If your login form has the username and password fields on different pages, use the [CI/CD variables](#available-cicd-variables) to configure [multi-step](#configuration-for-a-multi-step-login-form) login form authentication.
- Make sure the user isn't [logged out](#excluding-logout-urls) during the scan.

### Prerequisites

- You are using either the [DAST proxy-based analyzer](proxy-based.md) or the [DAST browser-based analyzer](browser_based.md).
- You know the URL of the login form of your application. Alternatively, you know how to navigate to the login form from the authentication URL (see [clicking to navigate to the login form](#clicking-to-navigate-to-the-login-form)).
- You have the username and password of the user you would like to authenticate as during the scan.
- You know the [selectors](#finding-an-elements-selector) of the username and password HTML fields that DAST will use to input the respective values.
- You know the element's [selector](#finding-an-elements-selector) that will submit the login form when selected.
- You have thought about how you can [verify](#verifying-authentication-is-successful) whether or not authentication was successful.
- You have checked the [known limitations](#known-limitations) to ensure DAST can authenticate to your application. 

### Available CI/CD variables

| CI/CD variable                                 | Type          | Description                                                                                                                                                                                                                                                                          |
|:-----------------------------------------------|:--------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `DAST_AUTH_COOKIES`                            | string        | Set to a comma-separated list of cookie names to specify which cookies are used for authentication.                                                                                                                                                                                  |
| `DAST_AUTH_REPORT`                             | boolean       | Used in combination with exporting the `gl-dast-debug-auth-report.html` artifact to aid in debugging authentication issues.                                                                                                                                                          |
| `DAST_AUTH_URL` <sup>1</sup>                   | URL           | The URL of the page containing the sign-in HTML form on the target website. `DAST_USERNAME` and `DAST_PASSWORD` are submitted with the login form to create an authenticated scan. Example: `https://login.example.com`.                                                             |
| `DAST_AUTH_VERIFICATION_LOGIN_FORM`            | boolean       | Verifies successful authentication by checking for the absence of a login form once the login form has been submitted.                                                                                                                                                               |
| `DAST_AUTH_VERIFICATION_SELECTOR`              | selector      | Verifies successful authentication by checking for presence of a selector once the login form has been submitted. Example: `css:.user-photo`.                                                                                                                                        |
| `DAST_AUTH_VERIFICATION_URL` <sup>1</sup>      | URL           | Verifies successful authentication by checking the URL in the browser once the login form has been submitted. Example: `"https://example.com/loggedin_page"`. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/207335) in GitLab 13.8.                                     |
| `DAST_BROWSER_PATH_TO_LOGIN_FORM` <sup>1</sup> | selector      | Comma-separated list of selectors that are selected prior to attempting to enter `DAST_USERNAME` and `DAST_PASSWORD` into the login form. Example: `"css:.navigation-menu,css:.login-menu-item"`. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/326633) in GitLab 14.1. |
| `DAST_EXCLUDE_URLS` <sup>1</sup>               | URLs          | The URLs to skip during the authenticated scan; comma-separated. Regular expression syntax can be used to match multiple URLs. For example, `.*` matches an arbitrary character sequence.                                                                                            |
| `DAST_FIRST_SUBMIT_FIELD`                      | string        | The `id` or `name` of the element that when selected submits the username form of a multi-page login process. For example, `css:button[type='user-submit']`. [Introduced](https://gitlab.com/gitlab-org/gitlab-ee/issues/9894) in GitLab 12.4.                                       |
| `DAST_PASSWORD` <sup>1</sup>                   | string        | The password to authenticate to in the website. Example: `P@55w0rd!`                                                                                                                                                                                                                 |
| `DAST_PASSWORD_FIELD`                          | string        | The selector of password field at the sign-in HTML form. Example: `id:password`                                                                                                                                                                                                      |
| `DAST_SUBMIT_FIELD`                            | string        | The `id` or `name` of the element that when selected submits the login form or the password form of a multi-page login process. For example, `css:button[type='submit']`. [Introduced](https://gitlab.com/gitlab-org/gitlab-ee/issues/9894) in GitLab 12.4.                          |
| `DAST_USERNAME` <sup>1</sup>                   | string        | The username to authenticate to in the website. Example: `admin`                                                                                                                                                                                                                     |
| `DAST_USERNAME_FIELD` <sup>1</sup>             | string        | The selector of username field at the sign-in HTML form. Example: `name:username`                                                                                                                                                                                                    |

1. Available to an on-demand proxy-based DAST scan.

### Update the target website

The target website, defined using the CI/CD variable `DAST_WEBSITE`, is the URL DAST uses to begin crawling your application.

For best crawl results on an authenticated scan, the target website should be a URL accessible only after the user is authenticated.
Often, this is the URL of the page the user lands on after they're logged in.

For example:

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://example.com/dashboard/welcome"
    DAST_AUTH_URL: "https://example.com/login"
```

### Configuration for a single-step login form

A single-step login form has all login form elements on a single page.
Configuration requires the CI/CD variables `DAST_AUTH_URL`, `DAST_USERNAME`, `DAST_USERNAME_FIELD`, `DAST_PASSWORD`, `DAST_PASSWORD_FIELD`, and `DAST_SUBMIT_FIELD` to be defined for the DAST job.

It is recommended to set up the URL and selectors of fields in the job definition YAML, for example: 

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://example.com"
    DAST_AUTH_URL: "https://example.com/login"
    DAST_USERNAME_FIELD: "css:[name=username]"
    DAST_PASSWORD_FIELD: "css:[name=password]"
    DAST_SUBMIT_FIELD: "css:button[type=submit]"
```

Do **not** define `DAST_USERNAME` and `DAST_PASSWORD` in the YAML job definition file as this could present a security risk. Instead, create them as masked CI/CD variables using the GitLab UI.
See [Custom CI/CI variables](../../../ci/variables/index.md#custom-cicd-variables) for more information.

### Configuration for a multi-step login form

A multi-step login form has two pages. The first page has a form with the username and a next submit button.
If the username is valid, a second form on the subsequent page has the password and the form submit button.

Configuration requires the CI/CD variables `DAST_AUTH_URL`, `DAST_USERNAME`, `DAST_USERNAME_FIELD`, `DAST_FIRST_SUBMIT_FIELD`, `DAST_PASSWORD`, `DAST_PASSWORD_FIELD`, and `DAST_SUBMIT_FIELD` to be defined for the DAST job.

It is recommended to set up the URL and selectors of fields in the job definition YAML, for example:

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://example.com"
    DAST_AUTH_URL: "https://example.com/login"
    DAST_USERNAME_FIELD: "css:[name=username]"
    DAST_FIRST_SUBMIT_FIELD: "css:button[name=next]"
    DAST_PASSWORD_FIELD: "css:[name=password]"
    DAST_SUBMIT_FIELD: "css:button[type=submit]"
```

Do **not** define `DAST_USERNAME` and `DAST_PASSWORD` in the YAML job definition file as this could present a security risk. Instead, create them as masked CI/CD variables using the GitLab UI.
See [Custom CI/CI variables](../../../ci/variables/index.md#custom-cicd-variables) for more information.

### Configuration for Single Sign-On (SSO)

If a user can log into an application, then in most cases, DAST will also be able to log in.
This is the case even when an application uses Single Sign-on. Applications using SSO solutions should configure DAST
authentication using the [single-step](#configuration-for-a-single-step-login-form) or [multi-step](#configuration-for-a-multi-step-login-form) login form configuration guides.

DAST supports authentication processes where a user is redirected to an external Identity Provider's site to log in.
Check the [known limitations](#known-limitations) of DAST authentication to determine if your SSO authentication process is supported.

### Clicking to navigate to the login form

Define `DAST_BROWSER_PATH_TO_LOGIN_FORM` to provide a path of elements to click on from the `DAST_AUTH_URL` so that DAST can access the 
login form. This is useful for applications that show the login form in a pop-up (modal) window or when the login form does not
have a unique URL.

For example:

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://example.com"
    DAST_AUTH_URL: "https://example.com/login"
    DAST_BROWSER_PATH_TO_LOGIN_FORM: "css:.navigation-menu,css:.login-menu-item"
```

### Excluding logout URLs

If DAST crawls the logout URL while running an authenticated scan, the user will be logged out, resulting in the remainder of the scan being unauthenticated.
It is therefore recommended to exclude logout URLs using the CI/CD variable `DAST_EXCLUDE_URLS`. DAST will not access any excluded URLs, ensuring the user remains logged in.

Provided URLs can be either absolute URLs, or regular expressions of URL paths relative to the base path of the `DAST_WEBSITE`. For example:

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://example.com/welcome/home"
    DAST_EXCLUDE_URLS: "https://example.com/logout,/user/.*/logout"
```

### Finding an element's selector

Selectors are used by CI/CD variables to specify the location of an element displayed on a page in a browser.
Selectors have the format `type`:`search string`. DAST searches for the selector using the search string based on the type.

| Selector type | Example                            | Description |
| ------------- | ---------------------------------- | ----------- |
| `css`         | `css:.password-field`              | Searches for a HTML element having the supplied CSS selector. Selectors should be as specific as possible for performance reasons. |
| `id`          | `id:element`                       | Searches for an HTML element with the provided element ID. |
| `name`        | `name:element`                     | Searches for an HTML element with the provided element name. |
| `xpath`       | `xpath://input[@id="my-button"]/a` | Searches for a HTML element with the provided XPath. Note that XPath searches are expected to be less performant than other searches. |
| None provided | `a.click-me`                       | Defaults to searching using a CSS selector. |

#### Find selectors with Google Chrome

Chrome DevTools element selector tool is an effective way to find a selector.

1. Open Chrome and navigate to the page where you would like to find a selector, for example, the login page for your site.
1. Open the `Elements` tab in Chrome DevTools with the keyboard shortcut `Command + Shift + c` in macOS or `Ctrl + Shift + c` in Windows.
1. Select the `Select an element in the page to select it` tool.
   ![search-elements](img/dast_auth_browser_scan_search_elements.png)
1. Select the field on your page that you would like to know the selector for.
1. Once the tool is active, highlight a field you wish to view the details of.
   ![highlight](img/dast_auth_browser_scan_highlight.png)
1. Once highlighted, you can see the element's details, including attributes that would make a good candidate for a selector.

In this example, the `id="user_login"` appears to be a good candidate. You can use this as a selector as the DAST username field by setting
`DAST_USERNAME_FIELD: "id:user_login"`.

#### Choose the right selector

Judicious choice of selector leads to a scan that is resilient to the application changing.

In order of preference, it is recommended to choose as selectors:

- `id` fields. These are generally unique on a page, and rarely change.
- `name` fields. These are generally unique on a page, and rarely change.
- `class` values specific to the field, such as the selector `"css:.username"` for the `username` class on the username field.
- Presence of field specific data attributes, such as the selector, `"css:[data-username]"` when the `data-username` field has any value on the username field.
- Multiple `class` hierarchy values, such as the selector `"css:.login-form .username"` when there are multiple elements with class `username` but only one nested inside the element with the class `login-form`.

When using selectors to locate specific fields we recommend you avoid searching on:

- Any `id`, `name`, `attribute`, `class` or `value` that is dynamically generated.
- Generic class names, such as `column-10` and `dark-grey`.
- XPath searches as they are less performant than other selector searches.
- Unscoped searches, such as those beginning with `css:*` and `xpath://*`.

## Verifying authentication is successful

Once DAST has submitted the login form, a verification process takes place
to determine if authentication succeeded. The scan will halt with an error if authentication is unsuccessful.

Following the submission of the login form, authentication is determined to be unsuccessful when:

- The login submit HTTP response has a `400` or `500` series status code.
- Any [verification check](#verification-checks) fails.
- An [authentication token](#authentication-tokens) with a sufficiently random value is not set during the authentication process.

### Verification checks

Verification checks run checks on the state of the browser once authentication is complete
to determine further if authentication succeeded.

DAST will test for the absence of a login form if no verification checks are configured.

#### Verify based on the URL

Define `DAST_AUTH_VERIFICATION_URL` as the URL displayed in the browser tab once the login form is successfully submitted.

DAST will compare the verification URL to the URL in the browser after authentication.
If they are not the same, authentication is unsuccessful.

For example:

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://example.com"
    DAST_AUTH_VERIFICATION_URL: "https://example.com/user/welcome"
```

#### Verify based on presence of an element

Define `DAST_AUTH_VERIFICATION_SELECTOR` as a [selector](#finding-an-elements-selector) that will find one or many elements on the page
displayed once the login form is successfully submitted. If no element is found, authentication is unsuccessful.
Searching for the selector on the page displayed when login fails should return no elements.

For example:

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://example.com"
    DAST_AUTH_VERIFICATION_SELECTOR: "css:.welcome-user"
```

#### Verify based on absence of a login form

Define `DAST_AUTH_VERIFICATION_LOGIN_FORM` as `"true"` to indicate that DAST should search for the login form on the
page displayed once the login form is successfully submitted. If a login form is still present after logging in, authentication is unsuccessful.

For example:

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://example.com"
    DAST_AUTH_VERIFICATION_LOGIN_FORM: "true"
```

### Authentication tokens

DAST records authentication tokens set during the authentication process.
Authentication tokens are loaded into new browsers when DAST opens them so the user can remain logged in throughout the scan.

To record tokens, DAST takes a snapshot of cookies, local storage, and session storage values set by the application before
the authentication process. DAST does the same after authentication and uses the difference to determine which were created
by the authentication process.

DAST considers cookies, local storage and session storage values set with sufficiently "random" values to be authentication tokens.
For example, `sessionID=HVxzpS8GzMlPAc2e39uyIVzwACIuGe0H` would be viewed as an authentication token, while `ab_testing_group=A1` would not.

The CI/CD variable `DAST_AUTH_COOKIES` can be used to specify the names of authentication cookies and bypass the randomness check used by DAST.
Not only can this make the authentication process more robust, but it can also increase vulnerability check accuracy for checks that
inspect authentication tokens.

For example:

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://example.com"
    DAST_AUTH_COOKIES: "sessionID,refreshToken"
```

## Known limitations

- DAST cannot bypass a CAPTCHA if the authentication flow includes one. Please turn these off in the testing environment for the application being scanned.
- DAST cannot handle multi-factor authentication like one-time passwords (OTP) by using SMS, biometrics, or authenticator apps. Please turn these off in the testing environment for the application being scanned.
- DAST cannot authenticate to applications that do not set an [authentication token](#authentication-tokens) during login.
- DAST cannot authenticate to applications that require more than two inputs to be filled out. Two inputs must be supplied, username and password.

## Troubleshooting

### Read the logs

The console output of the DAST CI/CD job shows information about the authentication process using the `AUTH` log module.
For example, the following log shows failed authentication for a multi-step login form.
Authentication failed because a home page should be displayed after login. Instead, the login form was still present.

```plaintext
2022-11-16T13:43:02.000 INF AUTH  attempting to authenticate
2022-11-16T13:43:02.000 INF AUTH  loading login page LoginURL=https://example.com/login
2022-11-16T13:43:10.000 INF AUTH  multi-step authentication detected
2022-11-16T13:43:15.000 INF AUTH  verifying if user submit was successful true_when="HTTP status code < 400"
2022-11-16T13:43:15.000 INF AUTH  requirement is satisfied, no login HTTP message detected want="HTTP status code < 400"
2022-11-16T13:43:20.000 INF AUTH  verifying if login attempt was successful true_when="HTTP status code < 400 and has authentication token and no login form found (no element found when searching using selector css:[id=email] or css:[id=password] or css:[id=submit])"
2022-11-24T14:43:20.000 INF AUTH  requirement is satisfied, HTTP login request returned status code 200 url=https://example.com/user/login?error=invalid%20credentials want="HTTP status code < 400"
2022-11-16T13:43:21.000 INF AUTH  requirement is unsatisfied, login form was found want="no login form found (no element found when searching using selector css:[id=email] or css:[id=password] or css:[id=submit])"
2022-11-16T13:43:21.000 INF AUTH  login attempt failed error="authentication failed: failed to authenticate user"
```

### When authentication succeeds and the scan doesn't crawl authenticated pages

Verify the captured authentication tokens are correct when a scan appears to authenticate and fails to crawl the authenticated pages of the application.
Names of cookies and session tokens determined by DAST to be authentication tokens are written to the log. For example:

```plaintext
2022-11-24T14:42:31.492 INF AUTH  authentication token cookies names=["sessionID"]
2022-11-24T14:42:31.492 INF AUTH  authentication token storage events keys=["token"]
```

See [authentication tokens](#authentication-tokens) for more information.

### Configure the authentication debug report

An authentication report can be saved as a CI/CD job artifact to assist with understanding the cause of an authentication failure.

The report contains steps during the login process, HTTP requests and responses, the Document Object Model (DOM) and screenshots.

![dast-auth-report](img/dast_auth_report.jpg)

An example configuration where the authentication debug report is exported may look like the following:

```yaml
dast:
  variables:
    DAST_WEBSITE: "https://example.com"
    DAST_AUTH_REPORT: "true"
  artifacts:
    paths: [gl-dast-debug-auth-report.html]
    when: always
```
