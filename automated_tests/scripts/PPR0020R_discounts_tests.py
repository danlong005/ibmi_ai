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
    command_line.setString("clrpfm TESTLIB/MBRDSCTS")
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
    return


def after_all_tests():
    # clean up authorization to program
    time.sleep(delay)
    screen = _session.getScreen()
    screenFields = screen.getScreenFields()
    command_line = screenFields.getField(0)
    command_line.setString("RMVLIBLE LIB(TESTLIB)")
    screen.sendKeys("[enter]")
    return


def discount_available_tests():
    try:
        # call the member inquiry program
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("MI")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # set membership to lookup
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        member_number_field = screenFields.getField(0)
        member_number_field.setString("10145416417")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # grab data from screen
        screen = _session.getScreen()
        screen_data = "".join(screen.getScreenAsChars())

        # make sure that discount is available
        expected_string = str("Discount Avlble")
        index = screen_data.find(expected_string)
        assert index != -1, "Expected string '" + expected_string + "' not found"

        time.sleep(delay)

        # exit program
        screen.sendKeys("[pf3]")
        screen.sendKeys("[pf3]")

        utils.passed(utils.currentFuncName())

    except:
        utils.failed(utils.currentFuncName())

    return


def discount_not_authorized_tests():
    try:
        # call the member inquiry program
        time.sleep(delay)
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("MI")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # set membership to lookup
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        member_number_field = screenFields.getField(0)
        member_number_field.setString("10145416417")
        screen.sendKeys("[enter]")

        # enter option 65 to select discount
        time.sleep(delay)
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        option_field = screenFields.getField(0)
        option_field.setString("65")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # grab data from screen
        screen = _session.getScreen()
        screen_data = "".join(screen.getScreenAsChars())

        # make sure that discount is available
        expected_string = str("Authorization Failure")
        index = screen_data.find(expected_string)
        assert index != -1, "Expected string '" + expected_string + "' not found"

        time.sleep(delay)
        screen.sendKeys("[enter]")
        screen.sendKeys("[pf3]")
        screen.sendKeys("[pf3]")

        utils.passed(utils.currentFuncName())

    except:
        utils.failed(utils.currentFuncName())

    return


def discount_works():
    try:
        # grant access to the discount program
        time.sleep(delay)
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("RUNSQLSTM SRCFILE(TESTLIB/ILESRC) SRCMBR(DSCNT0001S)")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # call the member inquiry program
        time.sleep(delay)
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("MI")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # set membership to lookup
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        member_number_field = screenFields.getField(0)
        member_number_field.setString("10145416417")
        screen.sendKeys("[enter]")

        # enter option 65 to select discount
        time.sleep(delay)
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        option_field = screenFields.getField(0)
        option_field.setString("65")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # grab data from screen
        screen = _session.getScreen()
        screen_data = "".join(screen.getScreenAsChars())

        # make sure that discount is available
        expected_string = str("Select Discount")
        index = screen_data.find(expected_string)
        assert index != -1, "Expected string '" + expected_string + "' not found"

        time.sleep(delay)

        # select the first discount
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        first_option = screenFields.getField(0)
        first_option.setString("X")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # check that we got the confirmation screen
        screen = _session.getScreen()
        chars = screen.getScreenAsChars()
        data = "".join(chars)
        expectedString = str("Confirm Discount Selection")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found as message returned."

        time.sleep(delay)

        # send valid option on confirmation screen
        screen = _session.getScreen()
        confirmation_option = screenFields.getField(0)
        confirmation_option.setString("Y")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # validate giving discount was successful
        screen = _session.getScreen()
        data = "".join(screen.getScreenAsChars())

        expectedString = str("Discount applied successfully.")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found as message returned."

        # cleanup and leave the program
        screen.sendKeys("[pf3]")
        screen.sendKeys("[pf3]")

        time.sleep(delay)


        # check the file to make sure it is entered
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("STRFEU TESTLIB/MBRDSCTS")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # validate giving discount was successful
        screen = _session.getScreen()
        data = "".join(screen.getScreenAsChars())

        # this is the correct membership and the discount that they should
        # have for this test
        expectedString = str("10145416417              100")
        index = data.find(expectedString)
        assert index != -1, "Expected string '" + expectedString + "' not found as message returned."
        screen.sendKeys("[pf3]")

        time.sleep(delay)

        # remove access to the discount program
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("RUNSQLSTM SRCFILE(TESTLIB/ILESRC) SRCMBR(DSCNT0002S)")
        screen.sendKeys("[enter]")

        utils.passed(utils.currentFuncName())

    except:
        utils.failed(utils.currentFuncName())

    return


def discount_fails_when_not_eligible_cc():
    try:
        # grant access to the discount program
        time.sleep(delay)
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("RUNSQLSTM SRCFILE(TESTLIB/ILESRC) SRCMBR(DSCNT0001S)")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # call the member inquiry program
        time.sleep(delay)
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("MI")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # set membership to lookup
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        member_number_field = screenFields.getField(0)
        member_number_field.setString("10038740212")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # grab data from screen
        screen = _session.getScreen()
        screen_data = "".join(screen.getScreenAsChars())

        # verify that discount is NOT available for ineligible members
        expected_string = str("Discount Avlble")
        index = screen_data.find(expected_string)
        assert index == -1, "Not expected string '" + expected_string + "' is found"


        # enter option 65 to select discount
        time.sleep(delay)
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        option_field = screenFields.getField(0)
        option_field.setString("65")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # grab data from screen
        screen = _session.getScreen()
        screen_data = "".join(screen.getScreenAsChars())

        # verify that the member is not eligible for the discount program
        expected_string = str("Member not eligible for Discount Program")
        index = screen_data.find(expected_string)
        assert index != -1, "Expected string '" + expected_string + "' not found"

        time.sleep(delay)
        screen.sendKeys("[pf3]")
        screen.sendKeys("[pf3]")

        time.sleep(delay)

        # remove access to the discount program
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("RUNSQLSTM SRCFILE(TESTLIB/ILESRC) SRCMBR(DSCNT0002S)")
        screen.sendKeys("[enter]")


        utils.passed(utils.currentFuncName())

    except:
        utils.failed(utils.currentFuncName())

    return


def discount_fails_when_not_eligible_has_discount_in_last_9_months():
    try:
        ########## should have be eligible ##############
        # grant access to the discount program
        time.sleep(delay)
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("RUNSQLSTM SRCFILE(TESTLIB/ILESRC) SRCMBR(DSCNT0001S)")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # give discounts for people over the last year
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("RUNSQLSTM SRCFILE(TESTLIB/ILESRC) SRCMBR(DSCNT0003S)")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # call the member inquiry program
        time.sleep(delay)
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        command_line = screenFields.getField(0)
        command_line.setString("MI")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # set membership to lookup
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        member_number_field = screenFields.getField(0)
        member_number_field.setString("10145416573")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # grab data from screen
        screen = _session.getScreen()
        screen_data = "".join(screen.getScreenAsChars())

        # verify that discount is NOT available for ineligible members
        expected_string = str("Discount Avlble")
        index = screen_data.find(expected_string)
        assert index != -1, "Expected string '" + expected_string + "' not found"

        time.sleep(delay)

        screen.sendKeys("[pf3]")

        time.sleep(delay)

        # set membership to lookup
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        member_number_field = screenFields.getField(0)
        member_number_field.setString("10145071659")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # grab data from screen
        screen = _session.getScreen()
        screen_data = "".join(screen.getScreenAsChars())

        # verify that discount is NOT available for ineligible members
        expected_string = str("Discount Avlble")
        index = screen_data.find(expected_string)
        assert index == -1, "Not expected string '" + expected_string + "' is found"

        time.sleep(delay)

        screen.sendKeys("[pf3]")

        time.sleep(delay)

        # set membership to lookup
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        member_number_field = screenFields.getField(0)
        member_number_field.setString("10145417704")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # grab data from screen
        screen = _session.getScreen()
        screen_data = "".join(screen.getScreenAsChars())

        # verify that discount is NOT available for ineligible members
        expected_string = str("Discount Avlble")
        index = screen_data.find(expected_string)
        assert index == -1, "Not expected string '" + expected_string + "' is found"

        time.sleep(delay)

        screen.sendKeys("[pf3]")

        time.sleep(delay)

        # set membership to lookup
        screen = _session.getScreen()
        screenFields = screen.getScreenFields()
        member_number_field = screenFields.getField(0)
        member_number_field.setString("10145072921")
        screen.sendKeys("[enter]")

        time.sleep(delay)

        # grab data from screen
        screen = _session.getScreen()
        screen_data = "".join(screen.getScreenAsChars())

        # verify that discount is NOT available for ineligible members
        expected_string = str("Discount Avlble")
        index = screen_data.find(expected_string)
        assert index == -1, "Not expected string '" + expected_string + "' is found"

        time.sleep(delay)

        screen.sendKeys("[pf3]")
        screen.sendKeys("[pf3]")

        utils.passed(utils.currentFuncName())

    except:
        utils.failed(utils.currentFuncName())

    return


# run the tests
print(" ")
print(" ")
print(" ")
print(" ---  STARTING RUN OF TESTS  ---   ")
print(" ")

before_all_tests()

# run tests here
discount_available_tests()
discount_not_authorized_tests()
discount_works()
discount_fails_when_not_eligible_cc()
discount_fails_when_not_eligible_has_discount_in_last_9_months()

after_all_tests()
