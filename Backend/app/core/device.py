from user_agents import parse


def parse_user_agent(user_agent: str | None) -> dict:
    if not user_agent:
        return {
            "device_name": "Unknown Device",
            "device_type": "Unknown",
            "browser": "Unknown",
            "operating_system": "Unknown",
        }

    ua = parse(user_agent)

    if ua.is_mobile:
        device_type = "Mobile"
    elif ua.is_tablet:
        device_type = "Tablet"
    elif ua.is_pc:
        device_type = "Desktop"
    else:
        device_type = "Unknown"

    return {
        "device_name": str(ua.device.family),
        "device_type": device_type,
        "browser": ua.browser.family,
        "operating_system": ua.os.family,
    }
