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
  - Settings, set `Valid Redirect URIs` to `*`, expand `Advanced Settings` and set `Access Token Lifespan` to `1 Hours`
  - Save

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

- Go to Roles

  - Add new Role `admin` with Description `${role_admin}`.
  - Add this Role into compositive role named `default-roles-master`. This role is automatically trusted in the 'Service Accounts' tab.

- Go to Clients

  - Click on `minio`
  - Service Accounts Roles
  - Add `admin` to assigned roles

- Check that `account` client_id has the role 'admin' assigned in the "Service Account Roles" tab.

## Launch Minio

Launch Minio (`docker-compose up -d`). Go to minio console home page: `http://172.17.0.1:9001`. Click on `Login with SSO`. You will be redirected to Keycloak to login. Once you login you will be redirected back to Minio.

## Custom access policies

We are going to simulate a scenario where you have two users: Alice and Bob with two buckets: A and B. Alice with all full read and write access to bucket A and B but Bob only read to bucket A.

### Create users

Go to Keycloak

- Go to Users

  - Add user
  - Username: `Alice`
  - Save
  - Go to Credentials
    - Fill password & password confirmation field
    - Uncheck `Temporary`
    - Set Password
  - Go to attributes
    - Add attribute with key: `policy` value: `minioSuperuser`
    - Save

- Go to Users
  - Add user
  - Username: `Bob`
  - Save
  - Go to Credentials
    - Fill password & password confirmation field
    - Uncheck `Temporary`
    - Set Password
  - Go to attributes
    - Add attribute with key: `policy` value: `minioUser`
    - Save

### Create buckets and custom policies

We are going to use Minio Client to create buckets and the policies.

```bash
docker pull minio/mc
docker run -it --rm --entrypoint=/bin/bash minio/mc
```

Add your minio server:

```bash
mc config host add minio http://172.17.0.1:9000 <MINIO_ROOT_USER> <MINIO_ROOT_PASSWORD>
```

Create buckets and put stuff inside:

```bash
mc mb minio/bucket-a
mc mb minio/bucket-b

echo "hello world!" > hello.txt
mc cp hello.txt minio/bucket-a/hello.a.txt
mc cp hello.txt minio/bucket-b/hello.b.txt
```

Create custom policies:

```bash
cat > minio_superuser.json << EOFL
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetBucketLocation"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::bucket-a/*",
        "arn:aws:s3:::bucket-b/*"
      ],
      "Sid": ""
    }
  ]
}
EOF

cat > minio_user.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:GetBucketLocation",
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::bucket-a/*"
      ],
      "Sid": ""
    }
  ]
}
EOF

mc admin policy add minio minioSuperuser minio_superuser.json
mc admin policy add minio minioUser minio_user.json
```

You can now access Minio Console and login with either Alice or Bob. You will see only bucket A for Bob and both buckets for Alice.

To learn more on how to design custom policies: https://docs.min.io/minio/baremetal/security/minio-identity-management/policy-based-access-control.html#minio-policy-actions.
