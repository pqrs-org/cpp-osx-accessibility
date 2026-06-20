#include <boost/ut.hpp>
#include <pqrs/osx/accessibility.hpp>

int main() {
  using namespace boost::ut;

  "application equality"_test = [] {
    pqrs::osx::accessibility::application a;
    a.set_name("TextEdit")
        .set_bundle_identifier("com.apple.TextEdit")
        .set_detection_source(pqrs::osx::accessibility::application::detection_source::workspace)
        .set_pid(123);

    pqrs::osx::accessibility::application b;
    b.set_name("TextEdit")
        .set_bundle_identifier("com.apple.TextEdit")
        .set_detection_source(pqrs::osx::accessibility::application::detection_source::workspace)
        .set_pid(123);

    expect(a == b);

    b.set_detection_source(pqrs::osx::accessibility::application::detection_source::ax_observer);

    expect(a != b);
  };

  "application accessors"_test = [] {
    pqrs::osx::accessibility::application a;

    expect(!a.get_name());
    expect(!a.get_bundle_identifier());
    expect(!a.get_bundle_path());
    expect(!a.get_file_path());
    expect(!a.get_pid());
    expect(a.get_detection_source() == pqrs::osx::accessibility::application::detection_source::none);

    a.set_name("TextEdit")
        .set_bundle_identifier("com.apple.TextEdit")
        .set_bundle_path("/System/Applications/TextEdit.app")
        .set_file_path("/System/Applications/TextEdit.app")
        .set_pid(123)
        .set_detection_source(pqrs::osx::accessibility::application::detection_source::workspace);

    expect(a.get_name() == "TextEdit");
    expect(a.get_bundle_identifier() == "com.apple.TextEdit");
    expect(a.get_bundle_path() == "/System/Applications/TextEdit.app");
    expect(a.get_file_path() == "/System/Applications/TextEdit.app");
    expect(a.get_pid() == 123);
    expect(a.get_detection_source() == pqrs::osx::accessibility::application::detection_source::workspace);
  };

  "focused_ui_element equality"_test = [] {
    pqrs::osx::accessibility::focused_ui_element a;
    a.set_role("AXTextArea")
        .set_subrole("AXSearchField")
        .set_identifier("spotlight-search")
        .set_window_position_x(10.0)
        .set_window_position_y(20.0)
        .set_window_size_width(30.0)
        .set_window_size_height(40.0);

    pqrs::osx::accessibility::focused_ui_element b;
    b.set_role("AXTextArea")
        .set_subrole("AXSearchField")
        .set_identifier("spotlight-search")
        .set_window_position_x(10.0)
        .set_window_position_y(20.0)
        .set_window_size_width(30.0)
        .set_window_size_height(40.0);

    expect(a == b);

    b.set_title("Search");

    expect(a != b);
  };

  "focused_ui_element accessors"_test = [] {
    pqrs::osx::accessibility::focused_ui_element e;

    expect(!e.get_role());
    expect(!e.get_subrole());
    expect(!e.get_role_description());
    expect(!e.get_title());
    expect(!e.get_description());
    expect(!e.get_identifier());
    expect(!e.get_window_position_x());
    expect(!e.get_window_position_y());
    expect(!e.get_window_size_width());
    expect(!e.get_window_size_height());

    e.set_role("AXTextArea")
        .set_subrole("AXSearchField")
        .set_role_description("text area")
        .set_title("Search")
        .set_description("Spotlight search")
        .set_identifier("spotlight-search")
        .set_window_position_x(10.0)
        .set_window_position_y(20.0)
        .set_window_size_width(30.0)
        .set_window_size_height(40.0);

    expect(e.get_role() == "AXTextArea");
    expect(e.get_subrole() == "AXSearchField");
    expect(e.get_role_description() == "text area");
    expect(e.get_title() == "Search");
    expect(e.get_description() == "Spotlight search");
    expect(e.get_identifier() == "spotlight-search");
    expect(e.get_window_position_x() == 10.0);
    expect(e.get_window_position_y() == 20.0);
    expect(e.get_window_size_width() == 30.0);
    expect(e.get_window_size_height() == 40.0);
  };

  return 0;
}
