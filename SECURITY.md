# Security policy

## Supported versions

1billion-ruby is pre-release (`v0.x`). Only the latest release gets security fixes.

## Report a problem

Please do not open a public issue for a security problem.

Use [GitHub private vulnerability reporting](https://github.com/clowk-in/1billion-ruby/security/advisories/new) for this repository. Say what you found, how to reproduce it, and which version you used.

You can expect an answer in a few days. We fix the problem, publish a release, and then say what happened. We credit you if you want.

A problem in the 1billion service itself (the API, the console, delivery) goes to the same place: we move it to the right team.

## Know before you use it

- **Keep the API key on the server.** Read it from an environment variable or a secret store. Never put it in a browser, a mobile app or a public repository.
- **One key for each app.** A key can send from the domains of its app only. Revoke a key in the console when it leaks.
- The client talks to `https://1billion.clowk.in` by default. `url:` with `http://` is for a local dev stack only.
