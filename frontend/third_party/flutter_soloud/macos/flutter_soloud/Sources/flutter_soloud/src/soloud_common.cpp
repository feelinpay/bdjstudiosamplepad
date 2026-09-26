#include "soloud_common.h"

#include <cstdlib>
#include <cstring>

char *soloudDuplicateString(const char *value) {
  const size_t length = std::strlen(value) + 1;
  auto *copy = static_cast<char *>(std::malloc(length));
  if (copy != nullptr) std::memcpy(copy, value, length);
  return copy;
}

#ifdef _IS_ANDROID_
#include <android/log.h>
#endif

#ifdef _IS_WIN_
#include <algorithm>
#endif

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#endif

void soloud_platform_log(const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
#ifdef _IS_ANDROID_
  __android_log_vprint(ANDROID_LOG_VERBOSE, "flutter_soloud NDK", fmt, args);
#elif defined(_IS_WIN_)
  char *buf = new char[4096];
  std::fill_n(buf, 4096, '\0');
  _vsprintf_p(buf, 4096, fmt, args);
  OutputDebugStringA(buf);
  delete[] buf;
#elif defined(__EMSCRIPTEN__)
  char buf[4096];
  vsnprintf(buf, sizeof(buf), fmt, args);
  emscripten_log(EM_LOG_CONSOLE, "%s", buf);
#else
  vprintf(fmt, args);
  fflush(stdout);
#endif
  va_end(args);
}
