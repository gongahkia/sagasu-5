import Foundation

enum NativeScraperDefinitions {
    static let landingURL = "https://www.smubondue.com/facility-booking-system-fbs"
    static let homeURL = "https://fbs.intranet.smu.edu.sg/home"

    static let microsoftLoginPattern = #"login\.microsoftonline\.com"#
    static let smuLoginPattern = #"login2\.smu\.edu\.sg"#
    static let dashboardPattern = #"https:\/\/fbs\.intranet\.smu\.edu\.sg\/"#

    enum Selectors {
        static let fbsLink = #"a[aria-label="SMU FBS"]"#
        static let emailInput = #"input[type="email"], #i0116"#
        static let nextButton = #"input[type="submit"], button[type="submit"], #idSIButton9"#
        static let redirectLink = #"a#redirectToIdpLink"#
        static let passwordInput = #"input#passwordInput"#
        static let passwordSubmit = #"div#submissionArea span#submitButton"#

        static let frameBottom = #"iframe#frameBottom"#
        static let frameContent = #"iframe#frameContent"#

        static let dateInput = #"input#DateBookingFrom_c1_textDate"#
        static let dateNext = #"a#BtnDpcNext"#
        static let datePrev = #"a#BtnDpcPrev"#
        static let timeFrom = #"select#TimeFrom_c1_ctl04"#
        static let timeTo = #"select#TimeTo_c1_ctl04"#

        static let buildingPicker = #"#DropMultiBuildingList_c1_textItem"#
        static let buildingOK = #"#DropMultiBuildingList_c1_panelContainer input[type="button"][value="OK"]"#
        static let floorPicker = #"#DropMultiFloorList_c1_textItem"#
        static let floorOK = #"#DropMultiFloorList_c1_panelContainer input[type="button"][value="OK"]"#
        static let facilityPicker = #"#DropMultiFacilityTypeList_c1_textItem"#
        static let facilityOK = #"#DropMultiFacilityTypeList_c1_panelContainer input[type="button"][value="OK"]"#
        static let capacity = #"select#DropCapacity_c1"#
        static let equipmentPicker = #"#DropMultiEquipmentList_c1_textItem"#
        static let equipmentOK = #"#DropMultiEquipmentList_c1_panelContainer input[type="button"][value="OK"]"#

        static let roomGrid = #"table#GridResults_gv"#
        static let roomRows = #"table#GridResults_gv tbody tr"#
        static let checkAvailability = #"a#CheckAvailability"#
        static let schedulerEvents = #"div.scheduler_bluewhite_event.scheduler_bluewhite_event_line0"#

        static let myBookingsTab = #"div#MyBookingsTab"#
        static let bookingsGrid = #"div#GridViewBooking_content"#
        static let bookingRows = #"div#GridViewBooking_content table tbody tr.row"#

        static let taskListTab = #"div#TaskListTab"#
        static let tasksGrid = #"div#GridViewTask"#
        static let taskRows = #"div#GridViewTask table tbody tr.row"#
    }

    enum JavaScript {
        static func querySelectorExists(_ selector: String) -> String {
            "Boolean(document.querySelector(\(quoted(selector))))"
        }

        static func querySelectorValue(_ selector: String) -> String {
            "(document.querySelector(\(quoted(selector))) || {}).value ?? null"
        }

        static func querySelectorAttribute(_ selector: String, attribute: String) -> String {
            "(document.querySelector(\(quoted(selector))) || {}).getAttribute?.(\(quoted(attribute))) ?? null"
        }

        static func click(_ selector: String) -> String {
            """
            (function() {
              const node = document.querySelector(\(quoted(selector)));
              if (!node) { return false; }
              node.click();
              return true;
            })()
            """
        }

        static func fill(_ selector: String, value: String) -> String {
            """
            (function() {
              const node = document.querySelector(\(quoted(selector)));
              if (!node) { return false; }
              node.focus();
              node.value = \(quoted(value));
              node.dispatchEvent(new Event('input', { bubbles: true }));
              node.dispatchEvent(new Event('change', { bubbles: true }));
              return true;
            })()
            """
        }

        static func select(_ selector: String, value: String) -> String {
            """
            (function() {
              const node = document.querySelector(\(quoted(selector)));
              if (!node) { return false; }
              node.value = \(quoted(value));
              node.dispatchEvent(new Event('change', { bubbles: true }));
              return true;
            })()
            """
        }

        static func clickText(_ text: String) -> String {
            """
            (function() {
              const wanted = \(quoted(text));
              const nodes = Array.from(document.querySelectorAll('*'));
              const match = nodes.find((node) => (node.textContent || '').trim() === wanted);
              if (!match) { return false; }
              match.click();
              return true;
            })()
            """
        }

        static func rowsMatrix(_ selector: String) -> String {
            """
            (function() {
              return Array.from(document.querySelectorAll(\(quoted(selector)))).map((row) =>
                Array.from(row.querySelectorAll('td')).map((cell) => (cell.innerText || '').trim())
              );
            })()
            """
        }

        static func roomNames(_ selector: String) -> String {
            """
            (function() {
              return Array.from(document.querySelectorAll(\(quoted(selector)))).map((row) => {
                const cells = row.querySelectorAll('td');
                return cells.length > 1 ? (cells[1].innerText || '').trim() : '';
              }).filter(Boolean);
            })()
            """
        }

        static func titleAttributes(_ selector: String) -> String {
            """
            (function() {
              return Array.from(document.querySelectorAll(\(quoted(selector)))).map((node) => node.getAttribute('title') || '').filter(Boolean);
            })()
            """
        }

        static func nestedFrameExpression(_ body: String) -> String {
            """
            (function() {
              const frameBottom = document.querySelector(\(quoted(Selectors.frameBottom)));
              if (!frameBottom || !frameBottom.contentDocument) { return null; }
              const frameContent = frameBottom.contentDocument.querySelector(\(quoted(Selectors.frameContent)));
              if (!frameContent || !frameContent.contentDocument) { return null; }
              const document = frameContent.contentDocument;
              \(body)
            })()
            """
        }

        private static func quoted(_ string: String) -> String {
            let escaped = string
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            return "\"\(escaped)\""
        }
    }
}
