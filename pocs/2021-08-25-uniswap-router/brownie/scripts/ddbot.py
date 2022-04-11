import json
import requests
from enum import Enum

class AlertType(Enum):
    Mute = 1
    Debug = 2
    Urgent = 3

def dd_report(msg, alert=AlertType.Mute):
    url = 'https://oapi.dingtalk.com/robot/send?access_token=e35950f4cf0132c2437c9f79cffe70bb284bb55fe4ec1c9dff4ef97e7c64aee7'

    headers = {'Content-Type': 'application/json;charset=utf-8'}
# alert = 'urgent'
    if alert is AlertType.Mute:
        with open('./scripts/data/log/tmp.log', 'w') as f:
            print(msg, file=f)
    if alert is AlertType.Debug:
        with open('./scripts/data/log/debug.log', 'w') as f:
            print(msg, file=f)
    data = {
        "msgtype": "text",
        "text": {
            "content": '[老板发财]:\n' + msg
        },
        "at": {
            "atMobiles": [  18374875572 if alert == 'urgent' else None
            ],
            "isAtAll": False  #此处为是否@所有人
        }
    }

    r = requests.post(url,data=json.dumps(data),headers=headers)
    return r.text