import sys, traceback

delay = 0.500

currentFuncName = lambda n=0: sys._getframe(n + 1).f_code.co_name

def passed(function_name=""):
    print("\033[32m.\033[0m " + function_name)
    return

def failed(function_name="", exception=None):
    print("\033[91mX\033[0m " + function_name)
    if exception is not None:
        print("  " + exception)
    return