# Terrakube

## Configure

## TODO

- Fix env variables and secrets in services
  - Move `InternalSecret` and `PatSecret`
    - [x] create `terrakube-env-secrets`
    - [ ] generate `InternalSecret` and `PatSecret`
          ```sh
          cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' |  fold -w 32 | \
            head -n 1 | base64 > InternalSecret.txt
          cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' |  fold -w 32 | \
            head -n 1 | base64 > PatSecret.txt
          ```
    - [ ] modify `terrakube-env-secrets` to load secrets from files
  - For `terrakube-api`
    - [x] split `terrakube-api-env-secrets-plain` in `terrakube-api-env-cm` and `terrakube-api-env-secret`
    - [x] modify `envFrom` for api `Deployment` to use new `ConfigMap` and `Secret`
    - [x] add targets in 'patches' files for Postgres
    - [x] add targets in 'patches' files for Redis
    - [x] add targets in 'patches' files for AWS S3 (MinIO)
    - [x] add `terrakube-env-secrets` in `envFrom`
  - For `terrakube-executor`
    - [x] split `terrakube-executor-secrets` in `terrakube-executor-env-cm` and `terrakube-executor-env-secret`
    - [x] modify `envFrom` for executor `Deployment` to use new `ConfigMap` and `Secret`
    - [x] add targets in 'patches' files for Redis
    - [x] add targets in 'patches' files for AWS S3 (MinIO)
    - [x] add `InternalSecret` in `env` from `terrakube-env-secrets`
  - For `terrakube-registry`
    - [x] split `terrakube-registry-secrets` in `terrakube-registry-env-cm` and `terrakube-registry-env-secret`
    - [x] modify `envFrom` to use new `ConfigMap` and `Secret`
    - [x] add targets in 'patches' files for AWS S3 (MinIO)
    - [x] add `terrakube-env-secrets` in `envFrom`
