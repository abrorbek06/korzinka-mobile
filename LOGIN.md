# Login

## Auth API

All routes mount at the root. Auth is JWT bearer by default; `@Public()` opt-outs are called out.

### `POST /auth/login`
- Auth: public
- Description: Log in with `{ username, password }`.
- Response: `{ accessToken, user }`.
- Notes: Username lookup is case-insensitive and requires `isActive = true`.

### `GET /auth/me`
- Auth: any authenticated user
- Description: Returns the current `AuthenticatedUser` injected by `JwtAuthGuard`.
