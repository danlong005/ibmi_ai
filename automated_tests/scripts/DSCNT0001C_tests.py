import time, sys

utilsdir = "./scripts/misc"
if utilsdir not in sys.path:
    sys.path.append(utilsdir)

import utils

delay = utils.delay
currentFuncName = utils.currentFuncName


def before_all_tests():
    # clear the existing member discounts
    screen = _session.getScreen()
    screenFields = screen.getScreenFields()
    command_line = screenFields.getField(0)
    command_line.setString("clrpfm TESTLIB/CUSTDISC")
    screen.sendKeys("[enter]")

    time.sleep(delay)

    # remove authorization to the discount programs
    screen = _session.getScreen()
    screenFields = screen.getScreenFields()
    command_line = screenFields.getField(0)
    command_line.setString("RUNSQLSTM SRCFILE(TESTLIB/ILESRC) SRCMBR(DSCNT0002S)")
    screen.sendKeys("[enter]")

    time.sleep(delay)

    # add testlib to the library list
    screen = _session.getScreen()
    screenFields = screen.getScreenFields()
    command_line = screenFields.getField(0)
    command_line.setString("ADDLIBLE LIB(TESTLIB) POSITION(*FIRST)")
    screen.sendKeys("[enter]")
    time.sleep(delay)

    # add PRODLIB to the library list
    screen = _session.getScreen()
    screenFields = screen.getScreenFields()
    command_line = screenFields.getField(0)
    command_line.setString("ADDLIBLE LIB(PRODLIB) POSITION(*LAST)")
    screen.sendKeys("[enter]")
    time.sleep(delay)

    # add yajl to the library list
    screen = _session.getScreen()
    screenFields = screen.getScreenFields()
    command_line = screenFields.getField(0)
    command_line.setString("ADDLIBLE LIB(YAJL) POSITION(*LAST)")
    screen.sendKeys("[enter]")
    time.sleep(delay)
    return

def after_all_tests():
    # clean up authorization to program
    time.sleep(delay)
    screen = _session.getScreen()
    screenFields = screen.getScreenFields()
    command_line = screenFields.getField(0)
    command_line.setString("RMVLIBLE LIB(TESTLIB)")
    screen.sendKeys("[enter]")

    time.sleep(delay)
    screen = _session.getScreen()
    screenFields = screen.getScreenFields()
    command_line = screenFields.getField(0)
    command_line.setString("RMVLIBLE LIB(YAJL)")
    screen.sendKeys("[enter]")
    return


def not_authorized_tests():
    try:
        # run command
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("call testlib/dscnt0001c parm('10038740212' '100.00' '4' '     ')")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # grab data from screen
        errorScreen = _session.getScreen()
        data = "".join(errorScreen.getScreenAsChars())

        # look for expected string
        expectedString = str("Authorization Failure")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found on error screen."

        # close program
        errorScreen.sendKeys("[enter]")

        time.sleep(delay)

        # verify message was returned
        screen = _session.getScreen()
        data = "".join(screen.getScreenAsChars())

        expectedString = str("Error: You do not have access to this function")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found as message returned."

        utils.passed(utils.currentFuncName())
    except Exception, e:
        utils.failed(utils.currentFuncName(), e)

    return

def invalid_usage_tests():
    try:
        # run command
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("call testlib/dscnt0001c parm(' ' '0' '0' '     ')")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # grab data from screen
        screen = _session.getScreen()
        data = "".join(screen.getScreenAsChars())

        # look for expected string
        expectedString = str("Error: Member number is required")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found as message returned."

        utils.passed(utils.currentFuncName())
    except Exception, e:
        utils.failed(utils.currentFuncName(), e)

    return


def select_discount_tests():
    try:
        # setup authorization to program
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("ADDLIBLE LIB(TESTLIB) POSITION(*FIRST)")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # grant access to the discount program
        time.sleep(delay)
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("RUNSQLSTM SRCFILE(TESTLIB/ILESRC) SRCMBR(DSCNT0001S)")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # run command
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("call testlib/dscnt0001c parm('10038740212' '100.00' '4' '     ')")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # grab data from screen
        screen = _session.getScreen()
        data = "".join(screen.getScreenAsChars())

        # look for expected string
        expectedString = str("Select Discount")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found as message returned."

        time.sleep(delay)

        # put invalid value in selection
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        first_option = screenFields.getField(0)
        first_option.setString("Y")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # grab data from screen
        screen = _session.getScreen()
        data = "".join(screen.getScreenAsChars())
        expectedString = str("Invalid option. Please try again.")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found as message returned."

        time.sleep(delay)

        # send valid option
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        first_option = screenFields.getField(0)
        first_option.setString("X")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # check that we got the confirmation screen
        screen = _session.getScreen()
        data = "".join(screen.getScreenAsChars())
        expectedString = str("Confirm Discount Selection")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found as message returned."

        # send invalid option on confirmation screen
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        confirmation_option = screenFields.getField(0)
        confirmation_option.setString("R")
        screen.sendKeys("[enter]")
        
        time.sleep(delay)
        screen = _session.getScreen()
        data = "".join(screen.getScreenAsChars())
        expectedString = str("Invalid Option. Please try again.")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found as message returned."

        time.sleep(delay)

        # send valid option on confirmation screen
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        confirmation_option = screenFields.getField(0)
        confirmation_option.setString("N")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        screen = _session.getScreen()
        data = "".join(screen.getScreenAsChars())
        expectedString = str("Select Discount")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found as message returned."

        # send valid selection for second discount
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        second_option = screenFields.getField(1)
        second_option.setString("X")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # send valid option on confirmation screen
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        confirmation_option = screenFields.getField(0)
        confirmation_option.setString("Y")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        screen = _session.getScreen()
        data = "".join(screen.getScreenAsChars())

        expectedString = str("Discount applied successfully")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found as message returned."

        time.sleep(delay)

        utils.passed(utils.currentFuncName())

    except Exception, e:
        utils.failed(utils.currentFuncName(), e)

    return


def no_codes_available_tests():
    try:
        # grant access to the discount program
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("RUNSQLSTM SRCFILE(TESTLIB/ILESRC) SRCMBR(DSCNT0001S)")
        screen.sendKeys("[enter]")
        
        time.sleep(delay)

        # remove the codes that are there
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("RUNSQLSTM SRCFILE(TESTLIB/ILESRC) SRCMBR(DSCNT0004S)")
        screen.sendKeys("[enter]")

        time.sleep(delay * 2)

        # run command with a channel that has no discount codes
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("call testlib/dscnt0001c parm('10038740212' '100.00' '4' '    ')")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # verify the no-codes screen is shown
        screen = _session.getScreen()
        data = "".join(screen.getScreenAsChars())
        expectedString = str("Look-Up Codes Failure")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found on no-codes screen."
        screen.sendKeys("[enter]")

        time.sleep(delay)

        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("RUNSQLSTM SRCFILE(TESTLIB/ILESRC) SRCMBR(DSCNT0005S)")
        screen.sendKeys("[enter]")

        utils.passed(utils.currentFuncName())
    except Exception, e:
        utils.failed(utils.currentFuncName())

    return


def cancel_with_f12_tests():
    try:
        # grant access to the discount program
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("RUNSQLSTM SRCFILE(TESTLIB/ILESRC) SRCMBR(DSCNT0001S)")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # run command
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("call testlib/dscnt0001c parm('10038740212' '100.00' '4' '     ')")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # verify selection screen is shown
        screen = _session.getScreen()
        data = "".join(screen.getScreenAsChars())
        expectedString = str("Select Discount")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found as message returned."

        # press F12 to cancel
        screen.sendKeys("[pf12]")

        time.sleep(delay)

        # verify we returned to the command line (selection screen gone)
        screen = _session.getScreen()
        data = "".join(screen.getScreenAsChars())
        expectedString = str("Select Discount")
        index = data.find(expectedString)
        assert index == -1, "Selection screen still showing after F12 cancel."

        utils.passed(utils.currentFuncName())
    except Exception, e:
        utils.failed(utils.currentFuncName(), e)

    return


def frequency_display_tests():
    try:
        frequency_descriptions = [
            ('1', 'Ann'),
            ('2', 'Semi'),
            ('3', 'Qtr'),
            ('4', 'Mo'),
            ('9', 'Unkn'),
        ]

        for freq, expected_desc in frequency_descriptions:
            # run command with this frequency
            screen = _session.getScreen()
            screenFields = screen.getScreenFields()
            command_line = screenFields.getField(0)
            command_line.setString("call testlib/dscnt0001c parm('10038740212' '100.00' '" + freq + "' '     ')")
            screen.sendKeys("[enter]")

            time.sleep(delay)

            # verify frequency description appears in the subfile
            screen = _session.getScreen()
            data = "".join(screen.getScreenAsChars())
            index = data.find(expected_desc)
            assert index != -1, "Expected frequency description '" + expected_desc + "' not found for frequency " + freq + "."

            # F12 to exit without applying
            screen.sendKeys("[pf12]")
            time.sleep(delay)

        utils.passed(utils.currentFuncName())
    except Exception, e:
        utils.failed(utils.currentFuncName(), e)

    return


print(" ")
print(" ")
print(" ")
print(" ---  STARTING RUN OF TESTS  ---   ")
print(" ")

before_all_tests()

#run tests here
not_authorized_tests()
invalid_usage_tests()
no_codes_available_tests()
select_discount_tests()
cancel_with_f12_tests()
frequency_display_tests()

after_all_tests()
