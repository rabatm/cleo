#!/usr/bin/env python3
"""Proxy HTTPS intercepteur minimal pour observer le trafic du CLI Kimi.
Génère une CA locale, signe un certificat par hôte, journalise requêtes/réponses.
Usage: python3 mitm.py 8899 /tmp/kimi_mitm_ca.crt  puis lancer le CLI avec
HTTPS_PROXY=http://127.0.0.1:8899 et les variables CA appropriées."""
import socket, ssl, select, subprocess, sys, os, threading, hashlib, datetime

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8899
CA_CRT = sys.argv[2] if len(sys.argv) > 2 else "/tmp/kimi_mitm_ca.crt"
WORK = "/tmp/kimi_mitm"
os.makedirs(WORK, exist_ok=True)
LOG = open(os.path.join(WORK, "traffic.log"), "w", buffering=1)
CA_KEY = os.path.join(WORK, "ca.key")

def run(cmd):
    subprocess.run(cmd, check=True, capture_output=True)

def ensure_ca():
    if os.path.exists(CA_CRT) and os.path.exists(CA_KEY):
        return
    run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
         "-keyout", CA_KEY, "-out", CA_CRT, "-days", "30",
         "-subj", "/CN=kimi-mitm-local", "-addext", "basicConstraints=critical,CA:TRUE"])

def cert_for(host):
    safe = hashlib.sha256(host.encode()).hexdigest()[:16]
    crt, key = f"{WORK}/{safe}.crt", f"{WORK}/{safe}.key"
    if not (os.path.exists(crt) and os.path.exists(key)):
        ext_file = f"{WORK}/{safe}.ext"
        with open(ext_file, "w") as f:
            f.write(f"subjectAltName=DNS:{host}\n")
        run(["openssl", "req", "-newkey", "rsa:2048", "-nodes", "-keyout", key,
             "-out", f"{WORK}/{safe}.csr", "-subj", f"/CN={host}"])
        run(["openssl", "x509", "-req", "-in", f"{WORK}/{safe}.csr",
             "-CA", CA_CRT, "-CAkey", CA_KEY, "-CAcreateserial",
             "-out", crt, "-days", "5", "-extfile", ext_file])
    return crt, key

def log(msg):
    LOG.write(f"[{datetime.datetime.now():%H:%M:%S}] {msg}\n")

def read_head(conn):
    data = b""
    while b"\r\n\r\n" not in data:
        chunk = conn.recv(65536)
        if not chunk:
            return None
        data += chunk
        if len(data) > 1_000_000:
            return None
    return data

def handle(client):
    try:
        head = read_head(client)
        if not head:
            return
        first, _, rest = head.partition(b"\r\n")
        parts = first.split(b" ")
        if len(parts) < 3 or parts[0] != b"CONNECT":
            return
        host, port = parts[1].decode().split(":")
        log(f"CONNECT {host}:{port}")
        upstream = socket.create_connection((host, int(port)), timeout=30)
        client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        crt, key = cert_for(host)
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(crt, key)
        try:
            tls_client = ctx.wrap_socket(client, server_side=True)
        except ssl.SSLError as e:
            log(f"TLS client échoué ({host}): {e} — pinning probable")
            upstream.close()
            return
        uctx = ssl.create_default_context()
        tls_up = uctx.wrap_socket(upstream, server_hostname=host)
        req = read_head(tls_client)
        if not req:
            return
        h_end = req.index(b"\r\n\r\n")
        headers = req[:h_end].decode("iso-8859-1")
        body = req[h_end + 4:]
        clen = 0
        for line in headers.split("\r\n")[1:]:
            if line.lower().startswith("content-length:"):
                clen = int(line.split(":")[1].strip())
        while len(body) < clen:
            chunk = tls_client.recv(65536)
            if not chunk:
                break
            body += chunk
        log(f"--> {headers.splitlines()[0]}\n{headers}")
        if body:
            log(f"--> CORPS: {body[:2000].decode('utf-8', 'replace')}")
        tls_up.sendall(req[:h_end + 4] + body)
        # Relayer la réponse (en streaming, on journalise l'en-tête)
        resp = read_head(tls_up)
        if resp:
            r_end = resp.index(b"\r\n\r\n")
            rhead = resp[:r_end].decode("iso-8859-1")
            log(f"<-- {rhead.splitlines()[0]}\n{rhead}")
            rbody = resp[r_end + 4:]
            rlen = 0
            chunked = False
            for line in rhead.split("\r\n")[1:]:
                if line.lower().startswith("content-length:"):
                    rlen = int(line.split(":")[1].strip())
                if line.lower().startswith("transfer-encoding:") and "chunked" in line:
                    chunked = True
            tls_client.sendall(resp)
            if chunked or rlen > len(rbody):
                # relais bidirectionnel jusqu'à fermeture, avec journalisation
                # des requêtes suivantes réutilisant la connexion (keep-alive)
                sockets = [tls_client, tls_up]
                pending = b""
                while True:
                    rl, _, _ = select.select(sockets, [], [], 30)
                    if not rl:
                        break
                    for s in rl:
                        try:
                            data = s.recv(65536)
                        except ssl.SSLError:
                            data = b""
                        if not data:
                            return
                        if s is tls_client:
                            pending += data
                            if b"\r\n" in pending:
                                first_line = pending.split(b"\r\n", 1)[0]
                                if first_line.split(b" ")[0] in (b"GET", b"POST", b"PUT", b"PATCH", b"DELETE"):
                                    log(f"--> (réutilisée) {first_line.decode('iso-8859-1', 'replace')}")
                                    if b"\r\n\r\n" in pending:
                                        blk = pending.split(b"\r\n\r\n", 1)
                                        hdr = blk[0].decode("iso-8859-1", "replace")
                                        log(hdr)
                                        if len(blk) > 1 and blk[1]:
                                            log(f"--> CORPS: {blk[1][:2000].decode('utf-8', 'replace')}")
                            pending = pending[-4096:]
                        (tls_up if s is tls_client else tls_client).sendall(data)
            elif rbody:
                log(f"<-- CORPS: {rbody[:2000].decode('utf-8', 'replace')}")
    except Exception as e:
        log(f"ERREUR: {type(e).__name__}: {e}")
    finally:
        try:
            client.close()
        except Exception:
            pass

ensure_ca()
srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", PORT))
srv.listen(50)
log(f"proxy prêt sur 127.0.0.1:{PORT}, CA: {CA_CRT}")
while True:
    c, _ = srv.accept()
    threading.Thread(target=handle, args=(c,), daemon=True).start()
