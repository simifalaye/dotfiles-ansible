#!/usr/bin/env python
import shutil

def is_installed_filter(app_name):
    return shutil.which(app_name) is not None

class FilterModule(object):
    def filters(self):
        return {
            "is_installed": is_installed_filter,
        }
