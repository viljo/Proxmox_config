<?php
// Nextcloud OIDC Configuration
// File: /var/www/nextcloud/config/config.php
// Requires: user_oidc app installed from App Store

// Add these settings to existing config.php array

// Allow local/private Keycloak server
'allow_local_remote_servers' => true,

// OIDC provider configuration
'oidc_login_provider_url' => 'https://keycloak.{{ public_domain }}/realms/master',
'oidc_login_client_id' => 'nextcloud',
'oidc_login_client_secret' => '{{ vault_nextcloud_oidc_secret }}',

// UI configuration
'oidc_login_auto_redirect' => false,
'oidc_login_end_session_redirect' => false,
'oidc_login_button_text' => 'Log in with Keycloak',
'oidc_login_hide_password_form' => false,

// Token and attribute configuration
'oidc_login_use_id_token' => true,
'oidc_login_attributes' => array(
    'id' => 'preferred_username',
    'name' => 'name',
    'mail' => 'email',
    'groups' => 'groups',
),

// User provisioning
'oidc_login_default_group' => 'oidc_users',
'oidc_login_disable_registration' => false,

// Advanced options
'oidc_login_scope' => 'openid profile email groups',
'oidc_login_proxy_ldap' => false,
'oidc_login_use_external_storage' => false,
'oidc_login_redir_fallback' => false,
'oidc_login_tls_verify' => true,

// Group mapping (optional)
// 'oidc_login_filter_allowed_values' => array(
//     'groups' => array('nextcloud-users', 'nextcloud-admins')
// ),
