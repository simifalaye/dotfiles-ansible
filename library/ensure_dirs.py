#!/usr/bin/python

from ansible.module_utils.basic import AnsibleModule
import os

def main():
    module_args = dict(
        dirs=dict(
            type='list',
            required=True,
            elements='dict',
            options=dict(
                path=dict(type='str', required=True),
                mode=dict(type='str', default='0755')
            )
        )
    )

    module = AnsibleModule(argument_spec=module_args, supports_check_mode=True)

    changed = False
    created = []

    for item in module.params['dirs']:
        path = os.path.expanduser(item['path'])
        mode = int(item.get('mode', '0755'), 8)

        if not os.path.exists(path):
            if module.check_mode:
                changed = True
                created.append(path)
                continue

            try:
                os.makedirs(path, mode=mode, exist_ok=True)
                changed = True
                created.append(path)
            except Exception as e:
                module.fail_json(msg=f"Failed to create {path}: {e}")

    module.exit_json(changed=changed, created=created)

if __name__ == '__main__':
    main()
