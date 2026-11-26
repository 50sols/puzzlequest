<?php
return [
    'version' => '1.0.0',
    'rules' => json_decode(file_get_contents(base_path('resources/product/APPROVED_PRODUCT_RULES.json')), true),
    'google_client_id' => env('GOOGLE_CLIENT_ID', '669275008728-h75erb2344tipd76enr2fahcd4h5frea.apps.googleusercontent.com'),
    'firebase_project' => env('FIREBASE_PROJECT_ID', 'puzzlequest50sols'),
    'firebase_credentials' => env('FIREBASE_CREDENTIALS'),
    'ad_units' => array_filter(explode(',', env('ADMOB_REWARDED_UNITS', ''))),
    'release_public_key' => env('RELEASE_PUBLIC_KEY'),
    'catalog_signing_key' => env('CATALOG_SIGNING_KEY'),
    'legal_approved' => env('LEGAL_APPROVED', false),
    'delete_enabled' => env('ACCOUNT_DELETION_ENABLED', false),
    'enforce_tls' => env('ENFORCE_HTTPS', true),
    'token_days' => 30,
    'support_email' => 'info@50sols.com',
];
