import json, os, sys, uuid, winreg, urllib.request, urllib.error
tok = os.environ.get("CURSEFORGE_TOKEN")
if not tok:
    k = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment")
    tok = winreg.QueryValueEx(k, "CURSEFORGE_TOKEN")[0]
pid, zip_path, changelog_path, display = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
meta = {"changelog": open(changelog_path, encoding="utf-8").read(), "changelogType": "text",
        "displayName": display, "gameVersions": [17053], "releaseType": "release"}
b = uuid.uuid4().hex
body = (f"--{b}\r\nContent-Disposition: form-data; name=\"metadata\"\r\n\r\n{json.dumps(meta)}\r\n"
        f"--{b}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{os.path.basename(zip_path)}\"\r\n"
        f"Content-Type: application/zip\r\n\r\n").encode() + open(zip_path, "rb").read() + f"\r\n--{b}--\r\n".encode()
req = urllib.request.Request(f"https://wow.curseforge.com/api/projects/{pid}/upload-file", data=body, method="POST",
                             headers={"X-Api-Token": tok, "Content-Type": f"multipart/form-data; boundary={b}"})
try:
    with urllib.request.urlopen(req, timeout=120) as r:
        print(r.status, r.read()[:300].decode())
except urllib.error.HTTPError as e:
    print(e.code, e.read()[:300].decode())
