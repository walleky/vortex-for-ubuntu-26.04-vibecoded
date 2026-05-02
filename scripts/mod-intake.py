#!/usr/bin/env python3
from __future__ import annotations

import argparse
import getpass
import json
import os
import re
import shutil
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

APP_ID = "proton-vortex"
APP_NAME = "proton-vortex-linux"
APP_VERSION = "0.3.0"
API_BASE = "https://api.nexusmods.com/v1"
ARCHIVE_EXTENSIONS = (
    ".zip",
    ".7z",
    ".rar",
    ".fomod",
    ".omod",
    ".tar",
    ".tar.gz",
    ".tgz",
)


def data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))


def app_home() -> Path:
    return data_home() / APP_ID


def key_file() -> Path:
    return app_home() / "nexus-api-key"


def downloads_dir() -> Path:
    return app_home() / "downloads"


def warn(message: str) -> None:
    print(message, file=sys.stderr)


def die(message: str, code: int = 1) -> None:
    print(f"Error: {message}", file=sys.stderr)
    raise SystemExit(code)


def action(kind: str, value: str) -> None:
    print(kind)
    print(value)


def read_api_key(required: bool = False) -> str | None:
    env_key = os.environ.get("NEXUS_API_KEY")
    if env_key:
        return env_key.strip()

    path = key_file()
    if path.exists():
        key = path.read_text(encoding="utf-8").strip()
        if key:
            return key

    if required:
        die("No Nexus API key configured. Run: proton-vortex api-key set")
    return None


def write_api_key(key: str) -> None:
    path = key_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(key.strip() + "\n", encoding="utf-8")
    os.chmod(path, 0o600)


def clear_api_key() -> None:
    try:
        key_file().unlink()
    except FileNotFoundError:
        pass


def api_headers(api_key: str | None = None) -> dict[str, str]:
    headers = {
        "Accept": "application/json",
        "Application-Name": APP_NAME,
        "Application-Version": APP_VERSION,
        "User-Agent": f"{APP_NAME}/{APP_VERSION} Linux",
    }
    protocol_version = os.environ.get("NEXUS_PROTOCOL_VERSION", "").strip()
    if protocol_version:
        headers["Protocol-Version"] = protocol_version
    if api_key:
        headers["APIKEY"] = api_key
    return headers


class ApiError(RuntimeError):
    pass


def http_json(url: str, api_key: str | None = None) -> tuple[object, dict[str, str]]:
    request = urllib.request.Request(url, headers=api_headers(api_key))
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            data = json.loads(response.read().decode("utf-8") or "{}")
            return data, dict(response.headers.items())
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(body)
            message = parsed.get("message") or parsed.get("error") or body
        except json.JSONDecodeError:
            message = body or exc.reason
        raise ApiError(f"{exc.code} {message}") from exc
    except urllib.error.URLError as exc:
        raise ApiError(str(exc.reason)) from exc


def api_url(path: str, query: dict[str, str | int | None] | None = None) -> str:
    url = API_BASE + path
    if query:
        clean = {key: value for key, value in query.items() if value is not None}
        if clean:
            url += "?" + urllib.parse.urlencode(clean)
    return url


def validate_key() -> object:
    key = read_api_key(required=True)
    data, headers = http_json(api_url("/users/validate"), key)
    return {"user": data, "rate_limits": rate_limits(headers)}


def rate_limits(headers: dict[str, str]) -> dict[str, str]:
    wanted = {}
    for key, value in headers.items():
        lowered = key.lower()
        if lowered.startswith("x-rl-"):
            wanted[lowered] = value
    return wanted


def parse_nxm(url: str) -> dict[str, object] | None:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme.lower() != "nxm":
        return None

    game = parsed.netloc
    parts = [urllib.parse.unquote(part) for part in parsed.path.split("/") if part]
    query = urllib.parse.parse_qs(parsed.query)

    if "collections" in parts:
        idx = parts.index("collections")
        slug = parts[idx + 1] if len(parts) > idx + 1 else None
        revision = None
        if "revisions" in parts:
            rev_idx = parts.index("revisions")
            revision = parts[rev_idx + 1] if len(parts) > rev_idx + 1 else None
        revision = revision or first_query(query, "revision")
        return {
            "kind": "collection",
            "game": game,
            "slug": slug,
            "revision": revision,
            "query": query,
        }

    if "mods" not in parts or "files" not in parts:
        return None

    mod_idx = parts.index("mods")
    file_idx = parts.index("files")
    try:
        mod_id = int(parts[mod_idx + 1])
        file_id = int(parts[file_idx + 1])
    except (IndexError, ValueError):
        return None

    return {
        "kind": "mod-file",
        "game": game,
        "mod_id": mod_id,
        "file_id": file_id,
        "key": first_query(query, "key"),
        "expires": first_query(query, "expires"),
        "query": query,
    }


def first_query(query: dict[str, list[str]], key: str) -> str | None:
    values = query.get(key)
    if not values:
        return None
    return values[0]


def safe_filename(name: str, fallback: str = "mod-download") -> str:
    name = urllib.parse.unquote(name or "").strip().strip(".")
    name = re.sub(r"[\\/:*?\"<>|]+", "_", name)
    name = re.sub(r"\s+", " ", name).strip()
    return name or fallback


def filename_from_url(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    return safe_filename(Path(parsed.path).name, "mod-download")


def filename_from_response(response: urllib.response.addinfourl, fallback: str) -> str:
    cd = response.headers.get("Content-Disposition", "")
    match = re.search(r"filename\*=UTF-8''([^;]+)", cd, flags=re.IGNORECASE)
    if match:
        return safe_filename(match.group(1), fallback)
    match = re.search(r'filename="?([^";]+)"?', cd, flags=re.IGNORECASE)
    if match:
        return safe_filename(match.group(1), fallback)
    return safe_filename(fallback, "mod-download")


def extension_for_content_type(content_type: str) -> str:
    content_type = content_type.lower()
    if "zip" in content_type:
        return ".zip"
    if "7z" in content_type or "7-zip" in content_type:
        return ".7z"
    if "rar" in content_type:
        return ".rar"
    if "gzip" in content_type:
        return ".gz"
    return ""


def looks_like_archive(path_or_url: str) -> bool:
    lowered = path_or_url.lower()
    return any(lowered.endswith(ext) for ext in ARCHIVE_EXTENSIONS)


def env_truthy(name: str) -> bool:
    return os.environ.get(name, "").strip().lower() in {"1", "true", "yes", "on"}


def linux_path_to_vortex_file_url(path: Path) -> str:
    resolved = path.expanduser().resolve()
    if not resolved.is_absolute():
        die(f"Expected an absolute path, got: {path}")
    windows_path = "Z:" + resolved.as_posix()
    return "file:///" + urllib.parse.quote(windows_path, safe="/:")


def unique_path(directory: Path, filename: str) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / filename
    if not target.exists():
        return target

    stem = target.name
    suffix = ""
    for ext in ARCHIVE_EXTENSIONS:
        if target.name.lower().endswith(ext):
            stem = target.name[: -len(ext)]
            suffix = target.name[-len(ext) :]
            break

    for index in range(1, 1000):
        candidate = directory / f"{stem}-{index}{suffix}"
        if not candidate.exists():
            return candidate
    die(f"Could not create a unique filename for {filename}")


def download_url(url: str, directory: Path, fallback_name: str) -> Path:
    request = urllib.request.Request(url, headers={"User-Agent": f"{APP_NAME}/{APP_VERSION}"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            content_type = response.headers.get("Content-Type", "").lower()
            filename = filename_from_response(response, filename_from_url(url) or fallback_name)
            if not looks_like_archive(filename):
                filename += extension_for_content_type(content_type)
            if not looks_like_archive(filename) and not (
                "application/octet-stream" in content_type
                or "application/zip" in content_type
                or "application/x-7z" in content_type
                or "application/x-rar" in content_type
            ):
                raise ApiError(f"URL did not look like a mod archive: {content_type or 'unknown content type'}")

            target = unique_path(directory, filename)
            part = target.with_suffix(target.suffix + ".part")
            with part.open("wb") as handle:
                shutil.copyfileobj(response, handle)
            part.replace(target)
            return target
    except urllib.error.HTTPError as exc:
        raise ApiError(f"{exc.code} {exc.reason}") from exc
    except urllib.error.URLError as exc:
        raise ApiError(str(exc.reason)) from exc


def file_info(game: str, mod_id: int, file_id: int, api_key: str) -> object:
    return http_json(api_url(f"/games/{game}/mods/{mod_id}/files/{file_id}"), api_key)[0]


def download_links(
    game: str,
    mod_id: int,
    file_id: int,
    api_key: str,
    key: str | None = None,
    expires: str | None = None,
) -> list[object]:
    query = {"key": key, "expires": expires} if key and expires else None
    data, _headers = http_json(
        api_url(f"/games/{game}/mods/{mod_id}/files/{file_id}/download_link", query),
        api_key,
    )
    if isinstance(data, list):
        return data
    if isinstance(data, dict) and isinstance(data.get("results"), list):
        return data["results"]
    raise ApiError("Nexus API did not return a download link list.")


def choose_download_uri(links: list[object]) -> str:
    for link in links:
        if not isinstance(link, dict):
            continue
        for key in ("URI", "uri", "url", "download_url", "binary_url"):
            value = link.get(key)
            if isinstance(value, str) and value:
                return value
    raise ApiError("Nexus API returned no usable download URI.")


def file_info_name(info: object, mod_id: int, file_id: int) -> str:
    if isinstance(info, dict):
        for key in ("file_name", "name", "display_name"):
            value = info.get(key)
            if isinstance(value, str) and value:
                return safe_filename(value, f"nexus-{mod_id}-{file_id}.7z")
    return f"nexus-{mod_id}-{file_id}.7z"


def write_metadata(archive: Path, metadata: dict[str, object]) -> None:
    sidecar = archive.with_suffix(archive.suffix + ".proton-vortex.json")
    sidecar.write_text(json.dumps(metadata, indent=2, sort_keys=True), encoding="utf-8")


def resolve_nxm(url: str) -> None:
    nxm = parse_nxm(url)
    if not nxm:
        warn("Could not parse NXM URL; asking Vortex to handle it directly.")
        action("install", url)
        return

    if nxm["kind"] == "collection":
        action("install", url)
        return

    if not env_truthy("PROTON_VORTEX_API_NXM"):
        warn("Passing Nexus mod NXM to Vortex's native download-and-install flow.")
        action("install", url)
        return

    api_key = read_api_key(required=False)
    if not api_key:
        warn("No Nexus API key configured; passing NXM URL to Vortex's native download-and-install flow.")
        action("install", url)
        return

    game = str(nxm["game"])
    mod_id = int(nxm["mod_id"])
    file_id = int(nxm["file_id"])
    key = nxm.get("key")
    expires = nxm.get("expires")

    try:
        info = file_info(game, mod_id, file_id, api_key)
        links = download_links(game, mod_id, file_id, api_key, key, expires)
        download = choose_download_uri(links)
        folder = downloads_dir() / "nexus" / game / str(mod_id)
        archive = download_url(download, folder, file_info_name(info, mod_id, file_id))
        write_metadata(
            archive,
            {
                "source": "nexus",
                "nxm": url,
                "game_domain": game,
                "mod_id": mod_id,
                "file_id": file_id,
                "downloaded_at": int(time.time()),
                "file_info": info,
            },
        )
        action("install-url", linux_path_to_vortex_file_url(archive))
    except ApiError as exc:
        warn(f"Nexus API download failed: {exc}")
        warn("Falling back to Vortex's native download-and-install flow.")
        action("install", url)


def resolve_http(url: str) -> None:
    try:
        folder = downloads_dir() / "external"
        archive = download_url(url, folder, filename_from_url(url))
        write_metadata(
            archive,
            {
                "source": "external-url",
                "url": url,
                "downloaded_at": int(time.time()),
            },
        )
        action("install-url", linux_path_to_vortex_file_url(archive))
    except ApiError as exc:
        warn(f"External download failed: {exc}")
        warn("Passing URL to Vortex instead.")
        action("download", url)


def resolve_file(value: str) -> None:
    if value.startswith("file://"):
        parsed = urllib.parse.urlparse(value)
        path = Path(urllib.request.url2pathname(parsed.path))
    else:
        path = Path(value).expanduser()

    if not path.exists():
        die(f"File does not exist: {path}")
    if path.is_dir():
        die("Vortex needs an archive file, not a folder. Zip the folder first.")
    if not looks_like_archive(path.name):
        warn("File does not have a common mod archive extension; passing it to Vortex anyway.")

    action("install-url", linux_path_to_vortex_file_url(path))


def resolve(value: str) -> None:
    lowered = value.lower()
    if lowered.startswith("nxm:"):
        resolve_nxm(value)
    elif lowered.startswith("http://") or lowered.startswith("https://"):
        resolve_http(value)
    elif lowered.startswith("file://") or Path(value).expanduser().exists():
        resolve_file(value)
    else:
        action("raw", value)


def cmd_api_key(args: argparse.Namespace) -> None:
    if args.key_command == "set":
        key = args.key or getpass.getpass("Nexus API key: ")
        if not key.strip():
            die("Empty API key.")
        write_api_key(key)
        print(f"Saved Nexus API key to {key_file()}")
    elif args.key_command == "clear":
        clear_api_key()
        print("Cleared Nexus API key.")
    elif args.key_command == "status":
        print("configured" if read_api_key(False) else "not configured")
    else:
        die("Unknown api-key command.", 2)


def cmd_api(args: argparse.Namespace) -> None:
    if args.api_command == "validate":
        print(json.dumps(validate_key(), indent=2, sort_keys=True))
        return

    api_key = read_api_key(required=True)
    if args.api_command == "file-info":
        data = file_info(args.game, int(args.mod_id), int(args.file_id), api_key)
        print(json.dumps(data, indent=2, sort_keys=True))
    elif args.api_command == "download-link":
        data = download_links(
            args.game,
            int(args.mod_id),
            int(args.file_id),
            api_key,
            args.key,
            args.expires,
        )
        print(json.dumps(data, indent=2, sort_keys=True))
    else:
        die("Unknown api command.", 2)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Linux intake helper for Proton Vortex.")
    sub = parser.add_subparsers(dest="command", required=True)

    resolve_parser = sub.add_parser("resolve", help="Resolve an NXM URL, URL, or archive path.")
    resolve_parser.add_argument("value")

    key_parser = sub.add_parser("api-key", help="Store or clear a Nexus Mods API key.")
    key_sub = key_parser.add_subparsers(dest="key_command", required=True)
    key_set = key_sub.add_parser("set")
    key_set.add_argument("key", nargs="?")
    key_sub.add_parser("clear")
    key_sub.add_parser("status")

    api_parser = sub.add_parser("api", help="Call small Nexus API helpers.")
    api_sub = api_parser.add_subparsers(dest="api_command", required=True)
    api_sub.add_parser("validate")
    file_info_parser = api_sub.add_parser("file-info")
    file_info_parser.add_argument("game")
    file_info_parser.add_argument("mod_id")
    file_info_parser.add_argument("file_id")
    download_parser = api_sub.add_parser("download-link")
    download_parser.add_argument("game")
    download_parser.add_argument("mod_id")
    download_parser.add_argument("file_id")
    download_parser.add_argument("--key")
    download_parser.add_argument("--expires")

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if args.command == "resolve":
        resolve(args.value)
    elif args.command == "api-key":
        cmd_api_key(args)
    elif args.command == "api":
        cmd_api(args)
    else:
        parser.error("Unknown command.")


if __name__ == "__main__":
    main()
