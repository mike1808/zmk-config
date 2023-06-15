#pragma once

#define XXX &none
#define ___ &trans

#define LAYOUT(\
  l00, l01, l02, l03, l04, l05,                          r00, r01, r02, r03, r04, r05, \
  l10, l11, l12, l13, l14, l15,                          r10, r11, r12, r13, r14, r15, \
  l20, l21, l22, l23, l24, l25,                          r20, r21, r22, r23, r24, r25, \
                                lrot,              rrot,                               \
            l30, l31, l32, l33,                          r30, r31, r32, r33            \
  ) \
  l00  l01  l02  l03  l04  l05                           r00  r01  r02  r03  r04  r05  \
  l10  l11  l12  l13  l14  l15                           r10  r11  r12  r13  r14  r15  \
  l20  l21  l22  l23  l24  l25                           r20  r21  r22  r23  r24  r25  \
                                lrot               rrot                                \
            l30  l31  l32  l33                           r30  r31  r32  r33            

#define LAYOUT_wrapper(...) LAYOUT(__VA_ARGS__)


#define SWAP_LAYOUT(\
  l00, l01, l02, l03, l04, l05,                          r00, r01, r02, r03, r04, r05, \
  l10, l11, l12, l13, l14, l15,                          r10, r11, r12, r13, r14, r15, \
  l20, l21, l22, l23, l24, l25,                          r20, r21, r22, r23, r24, r25, \
                                lrot,              rrot,                               \
            l30, l31, l32, l33,                          r30, r31, r32, r33            \
  ) \
  r05  r04  r03  r02  r01  r00                           l05  l04  l03  l02  l01  l00  \
  r15  r14  r13  r12  r11  r10                           l15  l14  l13  l12  l11  l10  \
  r25  r24  r23  r22  r21  r20                           l20  l21  l22  l23  l24  l25  \
                                rrot               lrot                                \
            r33  r32  r31  r30                           l33  l32  l31  l30            

#define SWAP_LAYOUT_wrapper(...) SWAP_LAYOUT(__VA_ARGS__)

#define ZMK_HELPER_STRINGIFY(x) #x

#define ZMK_SWP(name, tap) \
    / { \
        behaviors { \
            name: name { \
                label = ZMK_HELPER_STRINGIFY(ZB_ ## name); \
                compatible = "zmk,behavior-tap-dance"; \
                #binding-cells = <0>; \
                tapping-term-ms = <200>; \
                bindings = <tap>, <&mo SWP>; \
            }; \
        }; \
    };
