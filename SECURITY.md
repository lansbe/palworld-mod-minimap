# Security reporting

Report vulnerabilities privately through [GitHub security advisories](https://github.com/lansbe/palworld-mod-minimap/security/advisories/new).
Include the affected version, impact and a minimal reproduction using synthetic data.
Do not publish exploit details, credentials, saves or unredacted logs in a public issue.
There is no guaranteed response time. Security fixes target the latest stable release;
older releases may require upgrading.

## Local trust boundary

The runtime and MCP bridge operate with the local user's permissions. Only connect
trusted MCP clients and authorize the worlds/actions they may control. No network
listener is exposed. Refer to the runtime's [security model](https://github.com/lansbe/palworld-mods/blob/master/SECURITY.md).
Game-generated logs can contain personal data; inspect excerpts before sharing.
