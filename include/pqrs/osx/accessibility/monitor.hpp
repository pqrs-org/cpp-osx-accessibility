#pragma once

// (C) Copyright Takayama Fumihiko 2026.
// Distributed under the Boost Software License, Version 1.0.
// (See https://www.boost.org/LICENSE_1_0.txt)

#include "application.hpp"
#include "focused_ui_element.hpp"
#include "impl/impl.h"
#include <functional>
#include <memory>
#include <mutex>
#include <optional>

namespace pqrs {
namespace osx {
namespace accessibility {
class monitor final {
public:
  using frontmost_application_changed_callback = std::function<void(std::shared_ptr<application>)>;
  using focused_ui_element_changed_callback = std::function<void(std::shared_ptr<focused_ui_element>)>;

private:
  monitor(const monitor&) = delete;

  monitor() {
    pqrs_osx_accessibility_monitor_set_callback(static_cpp_callback);
  }

public:
  virtual ~monitor() {
    pqrs_osx_accessibility_monitor_unset_callback();
  }

  static void initialize_shared_monitor() {
    std::lock_guard<std::mutex> guard(shared_monitor_mutex_);

    shared_monitor_ = std::shared_ptr<monitor>(new monitor());
  }

  static void terminate_shared_monitor() {
    std::lock_guard<std::mutex> guard(shared_monitor_mutex_);

    shared_monitor_ = nullptr;
  }

  static std::weak_ptr<monitor> get_shared_monitor() {
    std::lock_guard<std::mutex> guard(shared_monitor_mutex_);

    return shared_monitor_;
  }

  void set_frontmost_application_changed_callback(frontmost_application_changed_callback callback) {
    std::lock_guard<std::mutex> guard(mutex_);

    frontmost_application_changed_callback_ = std::move(callback);
  }

  void set_focused_ui_element_changed_callback(focused_ui_element_changed_callback callback) {
    std::lock_guard<std::mutex> guard(mutex_);

    focused_ui_element_changed_callback_ = std::move(callback);
  }

  // Retrieves a snapshot of the current state and invokes the callbacks.
  // A typical use is to call this right after setting the callbacks.
  void trigger() {
    pqrs_osx_accessibility_monitor_trigger();
  }

private:
  static void static_cpp_callback(int32_t force,
                                  const char* application_name,
                                  const char* bundle_identifier,
                                  const char* bundle_path,
                                  const char* file_path,
                                  pid_t pid,
                                  const char* role,
                                  const char* subrole,
                                  const char* role_description,
                                  const char* title,
                                  const char* description,
                                  const char* identifier) {
    if (auto m = shared_monitor_; m) {
      m->cpp_callback(force,
                      application_name,
                      bundle_identifier,
                      bundle_path,
                      file_path,
                      pid,
                      role,
                      subrole,
                      role_description,
                      title,
                      description,
                      identifier);
    }
  }

  static std::optional<application> make_application(const char* application_name,
                                                     const char* bundle_identifier,
                                                     const char* bundle_path,
                                                     const char* file_path,
                                                     pid_t pid) {
    application value;
    auto has_value = false;

    if (application_name) {
      value.set_name(application_name);
      has_value = true;
    }
    if (bundle_identifier) {
      value.set_bundle_identifier(bundle_identifier);
      has_value = true;
    }
    if (bundle_path) {
      value.set_bundle_path(bundle_path);
      has_value = true;
    }
    if (file_path) {
      value.set_file_path(file_path);
      has_value = true;
    }
    if (pid != 0) {
      value.set_pid(pid);
      has_value = true;
    }

    if (has_value) {
      return value;
    }

    return std::nullopt;
  }

  static std::optional<focused_ui_element> make_focused_ui_element(const char* role,
                                                                   const char* subrole,
                                                                   const char* role_description,
                                                                   const char* title,
                                                                   const char* description,
                                                                   const char* identifier) {
    focused_ui_element value;
    auto has_value = false;

    if (role) {
      value.set_role(role);
      has_value = true;
    }
    if (subrole) {
      value.set_subrole(subrole);
      has_value = true;
    }
    if (role_description) {
      value.set_role_description(role_description);
      has_value = true;
    }
    if (title) {
      value.set_title(title);
      has_value = true;
    }
    if (description) {
      value.set_description(description);
      has_value = true;
    }
    if (identifier) {
      value.set_identifier(identifier);
      has_value = true;
    }

    if (has_value) {
      return value;
    }

    return std::nullopt;
  }

  void cpp_callback(int32_t force,
                    const char* application_name,
                    const char* bundle_identifier,
                    const char* bundle_path,
                    const char* file_path,
                    pid_t pid,
                    const char* role,
                    const char* subrole,
                    const char* role_description,
                    const char* title,
                    const char* description,
                    const char* identifier) {
    // `force` is non-zero when trigger() explicitly requests callbacks even if the snapshot is unchanged.
    auto current_application = make_application(application_name,
                                                bundle_identifier,
                                                bundle_path,
                                                file_path,
                                                pid);
    auto current_focused_ui_element = make_focused_ui_element(role,
                                                              subrole,
                                                              role_description,
                                                              title,
                                                              description,
                                                              identifier);

    frontmost_application_changed_callback application_callback;
    focused_ui_element_changed_callback focused_ui_element_callback;
    std::shared_ptr<application> application_ptr;
    std::shared_ptr<focused_ui_element> focused_ui_element_ptr;

    {
      std::lock_guard<std::mutex> guard(mutex_);

      if (force != 0 || last_application_ != current_application) {
        last_application_ = current_application;
        application_callback = frontmost_application_changed_callback_;
        if (current_application) {
          application_ptr = std::make_shared<application>(*current_application);
        }
      }

      if (force != 0 || last_focused_ui_element_ != current_focused_ui_element) {
        last_focused_ui_element_ = current_focused_ui_element;
        focused_ui_element_callback = focused_ui_element_changed_callback_;
        if (current_focused_ui_element) {
          focused_ui_element_ptr = std::make_shared<focused_ui_element>(*current_focused_ui_element);
        }
      }
    }

    if (application_callback) {
      application_callback(application_ptr);
    }

    if (focused_ui_element_callback) {
      focused_ui_element_callback(focused_ui_element_ptr);
    }
  }

  inline static std::shared_ptr<monitor> shared_monitor_;
  inline static std::mutex shared_monitor_mutex_;

  std::mutex mutex_;
  frontmost_application_changed_callback frontmost_application_changed_callback_;
  focused_ui_element_changed_callback focused_ui_element_changed_callback_;
  std::optional<application> last_application_;
  std::optional<focused_ui_element> last_focused_ui_element_;
};
} // namespace accessibility
} // namespace osx
} // namespace pqrs
