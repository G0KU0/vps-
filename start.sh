#!/bin/bash
set -e

BORE_PORT="${BORE_PORT:-48252}"

echo "════════════════════════════════════════"
echo "  🐧 Linux Server"
echo "  🔑 Jelszó: 2003"
echo "  📌 SSH port: ${BORE_PORT}"
echo "════════════════════════════════════════"

echo 'root:2003' | chpasswd
echo 'admin:2003' | chpasswd

mkdir -p /var/run/screen && chmod 777 /var/run/screen && chmod +t /var/run/screen
mkdir -p /var/log/screen && chmod 777 /var/log/screen
mkdir -p /root/.screen-sessions

cat > /var/www/html/sftp.txt << EOF
Tunnel indítása...
ssh root@bore.pub -p ${BORE_PORT}
Jelszó: 2003
EOF

cat > /usr/local/bin/bore-wrapper.sh << BORE
#!/bin/bash
while true; do
    /usr/local/bin/bore local 22 --to bore.pub --port ${BORE_PORT} 2>&1
    sleep 5
done
BORE
chmod +x /usr/local/bin/bore-wrapper.sh

cat > /usr/local/bin/keep-alive.sh << 'KA'
#!/bin/bash
while true; do
    sleep 60
    curl -s -o /dev/null http://127.0.0.1:6969/health 2>/dev/null
done
KA
chmod +x /usr/local/bin/keep-alive.sh

cat > /usr/local/bin/update-sftp.sh << SFTP
#!/bin/bash
while sleep 5; do
    if grep -q 'bore\.pub' /var/log/bore.log 2>/dev/null; then
        SC=\$(screen -list 2>/dev/null | grep -c "\..*(" || echo 0)
        SAVED=\$(ls /root/.screen-sessions/*.cmd 2>/dev/null | wc -l || echo 0)
        cat > /var/www/html/sftp.txt << EOF
AKTIV
SSH: ssh root@bore.pub -p ${BORE_PORT}
Jelszó: 2003
Host: bore.pub
Port: ${BORE_PORT}
📺 Screens: \${SC} fut / \${SAVED} mentve
EOF
    fi
done
SFTP
chmod +x /usr/local/bin/update-sftp.sh

cat > /usr/local/bin/auto-cleanup.sh << 'AC'
#!/bin/bash
while true; do
    [ "$(date +%H)" -eq 3 ] && /usr/local/bin/cleanup.sh && sleep 3600
    sleep 300
done
AC
chmod +x /usr/local/bin/auto-cleanup.sh

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
