const fs = require('fs');
const OUTPUT = 'd:/k/wink/teknik_bakis/.agents/tasks/token_inspect.json';

const configPath = 'C:/Users/k/.config/configstore/firebase-tools.json';
const raw = JSON.parse(fs.readFileSync(configPath, 'utf8'));

// Show structure without actual token values
const safe = {
  top_level_keys: Object.keys(raw),
  tokens_keys: raw.tokens ? Object.keys(raw.tokens) : 'NO TOKENS',
  has_access_token: !!(raw.tokens && raw.tokens.access_token),
  has_refresh_token: !!(raw.tokens && raw.tokens.refresh_token),
  user_email: raw.user ? raw.user.email : 'no user',
  // Show first chars of access_token if exists (to check validity)
  access_token_preview: raw.tokens && raw.tokens.access_token 
    ? raw.tokens.access_token.substring(0, 20) + '...' 
    : 'none',
};

// Also check if there's a token_expiry
if (raw.tokens) {
  safe.token_expiry = raw.tokens.token_expiry || raw.tokens.expires_in || 'not found';
}

fs.writeFileSync(OUTPUT, JSON.stringify(safe, null, 2));
