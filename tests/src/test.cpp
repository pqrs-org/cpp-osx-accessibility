#include <boost/ut.hpp>
#include <pqrs/osx/accessibility.hpp>

int main(void) {
  using namespace boost::ut;

  "application equality"_test = [] {
    pqrs::osx::accessibility::application a;
    a.set_name("Spotlight")
        .set_bundle_identifier("com.apple.Spotlight")
        .set_pid(123);

    pqrs::osx::accessibility::application b;
    b.set_name("Spotlight")
        .set_bundle_identifier("com.apple.Spotlight")
        .set_pid(123);

    expect(a == b);
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

  return 0;
}
