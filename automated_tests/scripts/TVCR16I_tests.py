import sys, time

utilsdir = "./scripts/misc"
if utilsdir not in sys.path:
    sys.path.append(utilsdir)

import utils

delay = utils.delay

def before_all_tests():
    time.sleep(delay)
    return

def after_all_tests():
    time.sleep(delay)
    return


def program_shows_nothing_when_associate_does_not_exist():
    try:
        time.sleep(delay)

        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("call tvcr16i parm('000000000' ' ')")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        programScreen = _session.getScreen()
        data = "".join(programScreen.getScreenAsChars())

        # look for expected string
        expectedString = str("Agent ID:             ")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found on error screen."

        time.sleep(delay)
        programScreen.sendKeys("[pf3]")


        utils.passed(utils.currentFuncName())
    except:
        utils.failed(utils.currentFuncName())

    return


def screen_shows_column_headers():
    try:
        time.sleep(delay)

        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("call tvcr16i parm('900903391' ' ')")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        programScreen = _session.getScreen()
        data = "".join(programScreen.getScreenAsChars())

        expected_headers = [
            "Associate Upline Inquiry",
            "Agent ID:",
            "ASSOCIATE NAME",
            "-MEMBERSHIPS-",
            "-POWER-",
            "F3=Exit",
            "F17=Coded Bonus Upline",
        ]

        for header in expected_headers:
            index = data.find(header)
            assert index != -1, "Expected header '" + header + "' not found on screen."

        programScreen.sendKeys("[pf3]")

        utils.passed(utils.currentFuncName())
    except:
        utils.failed(utils.currentFuncName())

    return


def program_displays():
    try:
        time.sleep(delay)

        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("call tvcr16i parm('900903391' ' ')")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        programScreen = _session.getScreen()
        data = "".join(programScreen.getScreenAsChars())

        upline = ["900903391 INTERNATIONAL,INC, P",
                  "127196095 LOGIC INC, CERTAINTY",
                  "129335618 CARRUTHERS LLC, BRIA",
                  "106554660 LSC GROUP, KIAT VORI",
                  "106109689 ROGERS, ROENSUK",
                  "104357835 CARRUTHERS LLC, BRIA",
                  "104377825 HO ENTERPRISES, GUNG",
                  "900917747 GROUP LLC, L-K MARKE",
                  "104351671 GROUP LLC, L-K MARKE",
                  "876 TPN",
                  "1 CORPORATE OFFICE, LE"]

        previous_index = -1
        index = 0
        for associate in upline:
            # look for expected string
            print("looking for " + associate)
            expectedString = str(associate)
            index = data.find(expectedString)
            assert index != -1, "Expected string '" + expectedString + "' not found on error screen."

            # make sure that the upline records are in the expected order
            assert previous_index < index, "Upline records are not in the expected order."
            previous_index = index

        time.sleep(delay)

        programScreen = _session.getScreen()
        programScreen.sendKeys("[pf17]")

        time.sleep(delay)

        programScreen = _session.getScreen()
        data = "".join(programScreen.getScreenAsChars())

        # look for expected string
        expectedString = str("CODR160I                     Coded Bonus Upline")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found on error screen."

        time.sleep(delay)
        programScreen.sendKeys("[pf3]")

        time.sleep(delay)
        programScreen.sendKeys("[pf3]")


        utils.passed(utils.currentFuncName())
    except:
        utils.failed(utils.currentFuncName())

    return



print(" ")
print(" ")
print(" ")
print(" ---  STARTING RUN OF TESTS  ---   ")
print(" ")

before_all_tests()

# run tests here
screen_shows_column_headers()
program_displays()
program_shows_nothing_when_associate_does_not_exist()

after_all_tests()
