import logging
from aiohttp import web
import tomlkit
import json
import os


routes = web.RouteTableDef()


@routes.post("/answer")
async def answer(request: web.Request):
    logging.info(f"Received request from peer '{request.remote}'")

    try:
        data = await request.json()
    except:
        data = None

    print(json.dumps(data, indent=4))
    uuid = data["dmi"]["system"]["uuid"]
    print(uuid)

    var = uuid.split("-")[4]
    sysname = f"pve-{var}.lan"

    file_contents = app.get("answer_file", None)
    file_contents["global"]["fqdn"] = sysname
    file_contents["global"]["root-password"] = os.environ.get("PVE_ROOT_PASSWORD", "changeme")

    if file_contents is None:
        return web.Response(status=404, text="not found")

    return web.Response(text=tomlkit.dumps(file_contents))


@routes.post("/postinst")
async def postinst(request: web.Request):
    logging.info(f"Received postinst request from peer '{request.remote}'")

    try:
        data = await request.json()
    except:
        data = None

    print(json.dumps(data, indent=4))
    return web.Response(text="")


if __name__ == "__main__":
    app = web.Application()

    with open("proxmox.toml") as answer_file:
        file_contents = answer_file.read()

    app["answer_file"] = tomlkit.parse(file_contents)

    print(json.dumps(app["answer_file"], indent=4))

    logging.basicConfig(level=logging.INFO)

    app.add_routes(routes)
    web.run_app(app, host="0.0.0.0", port=8090)
