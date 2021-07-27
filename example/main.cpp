#include <iostream>
#include <pqrs/osx/accessibility.hpp>

int main(void) {
  std::cout << "is_process_trusted: " << pqrs::osx::accessibility::is_process_trusted_with_prompt() << std::endl;

  return 0;
}
