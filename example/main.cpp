#include <iostream>
#include <pqrs/osx/accessibility.hpp>
#include <pqrs/osx/autorelease_pool.hpp>

int main() {
  pqrs::osx::autorelease_pool::execute_with_autorelease_pool([] {
    std::cout << "is_process_trusted: " << pqrs::osx::accessibility::is_process_trusted_with_prompt() << std::endl;
  });

  return 0;
}
