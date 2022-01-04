# minio-keycloak

Minion (S3) with Keycloak for authentication &amp; authorization

## Configure .env

Create a .env file with the following values:

```bash
KEYCLOAK_ADMIN_LOGIN= # Keycloak admin user
KEYCLOAK_ADMIN_PASSWORD= # Keycloak admin user password

MINIO_ROOT_USER= # Minio root user
MINIO_ROOT_PASSWORD= # Minio root user passwordadmin

MINIO_SERVER_URL=http://172.17.0.1:9000 # URL of Minio server
MINIO_BROWSER_REDIRECT_URL=http://172.17.0.1:9001 # URL of Minion console

MINIO_IDENTITY_OPENID_CONFIG_URL=https://172.17.0.1:8443/auth/realms/master/.well-known/openid-configuration # Keycloak URL
MINIO_IDENTITY_OPENID_CLIENT_ID=minio # Keycloak client
MINIO_IDENTITY_OPENID_CLIENT_SECRET= # Keycloak client secret from section above
```

## Certificates

Run the `setup_certs.sh` script to generate Keycloak certificates

```bash
bash setup_certs.sh
```

## Configure Keycloak Realm

Launch Keycloak (`docker-compose up -d keycloak`) and go to admin console: `localhost:8443`. Login with the credentitals from the .env.

- Go to Clients

  - Click on create

    - Put client ID: `minio`
    - Save

- Go to Clients

  - Click on `minio`
    - Settings
    - Change `Access Type` to `confidential`.
    - Set `Service Accounts Enabled` to `On`
    - Set `Valid Redirect URIs` to `*`
    - Expand `Advanced Settings` and set `Access Token Lifespan` to `1 Hours`
    - Save
  - Click on credentials tab
    - Copy the `Secret` to clipboard.
    - This value is needed for `MINIO_IDENTITY_OPENID_CLIENT_SECRET` for MinIO.

- Go to Users

  - Click on the user
  - Attribute, add a new attribute `Key` is `policy`, `Value` is name of the `policy` on MinIO (ex: `readwrite`)
  - Add and Save

- Go to Clients

  - Click on `minio`
  - Mappers
  - Create
    - `Name` with any text
    - `Mapper Type` is `User Attribute`
    - `User Attribute` is `policy`
    - `Token Claim Name` is `policy`
    - `Claim JSON Type` is `string`
  - Save

- Go to Clients

  - Click on `minio`
  - Mappers
  - Create
    - `Name` with any text
    - `Mapper Type` is `Audience`
    - `Included Client Audience` is `security-admin-console`
  - Save

- Go to Clients

  - Click on `minio`
  - Service Accounts Roles
  - Add `admin` to assigned roles

- Go to Roles

  - Add new Role `admin` with Description `${role_admin}`.
  - Add this Role into compositive role named `default-roles-master`. This role is automatically trusted in the 'Service Accounts' tab.

- Check that `minio` client_id has the role 'admin' assigned in the "Service Account Roles" tab.

## Launch Minio

Launch Minio (`docker-compose up -d`). Go to minio console home page: `http://172.17.0.1:9001`. Click on `Login with SSO`. You will be redirected to Keycloak to login. Once you login you will be redirected back to Minio.
