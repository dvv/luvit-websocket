#include <stdint.h>
#include <stdlib.h>

//void encode(uint8_t *buf, uint32_t len) {
void encode(const char *buf, uint32_t len) {

  uint8_t *p = (uint8_t *) buf;
  uint32_t i;

  // compose header
  if (len < 126) {
    p[0] = 0x80 + 1;
    p[1] = 0x80 | len;
    p += 2;
  } else if (len < 65536) {
    p[0] = 0x80 + 1;
    p[1] = 0x80 | 0x7E;
    p[2] = (len >> 8) & 0xFF;
    p[3] = len & 0xFF;
    p += 4;
  } else {
    p[0] = 0x80 + 1;
    p[1] = 0x80 | 0x7F;
    uint32_t len2 = len;
    for (i = 8; i > 0; --i) {
      p[i+1] = len2 & 0xFF;
      len2 = len2 >> 8;
    }
    p += 10;
  }

  // create mask
  uint32_t ki;
  uint8_t *key = p;
  // TODO: srand? or read /dev/urandom?
  for (ki = 0; ki < 4; ++ki) {
    key[ki] = rand() & 0xFF;
  }
  p += 4;

  // mask buffer content
  for (i = 0, ki = 0; i < len; ++i) {
    p[i] ^= key[ki];
    if (++ki > 3) ki = 0;
  }

}

void mask(uint8_t *buf, uint8_t *key, uint32_t len) {

  uint8_t *p = buf;

  // mask buffer content
  uint32_t i, ki;
  for (i = 0, ki = 0; i < len; ++i) {
    p[i] ^= key[ki];
    if (++ki > 3) ki = 0;
  }

}
