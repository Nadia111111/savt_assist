// lib/widgets/savt_logo_data.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Встроенные байты букв логотипа SAVT для мгновенной отрисовки без задержек сети (включая Web)
class SavtLogoData {
  static Uint8List? _sBytes;
  static Uint8List? _avtBytes;

  static Uint8List get sBytes {
    if (_sBytes == null) {
      try {
        _sBytes = base64Decode(_sBase64);
      } catch (e) {
        debugPrint('SavtLogoData sBytes decode error: ' + e.toString());
        _sBytes = Uint8List(0);
      }
    }
    return _sBytes!;
  }

  static Uint8List get avtBytes {
    if (_avtBytes == null) {
      try {
        _avtBytes = base64Decode(_avtBase64);
      } catch (e) {
        debugPrint('SavtLogoData avtBytes decode error: ' + e.toString());
        _avtBytes = Uint8List(0);
      }
    }
    return _avtBytes!;
  }

  static const String _sBase64 =
      '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';

  static const String _avtBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAASEAAABWCAYAAACATSDWAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8'
      'YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAABYRSURBVHhe7Z15cF1XfcdpSoEUSoHS0hS6QNLSUgpNSpsW'
      'mAKlE5ihbCVsBQo0kIQQQlvoACW02vd9tWxZsizL2penJ8mWZcmyFMm2JCvWEsnao82SLMvWvkvtfJnz'
      'Jnd+Y797dfS7793tM6P/fN7vnuvzfu98z/L9vepVPiQiIuJN5eXl32xtbY1tbW2NM9NfZWXlk5GRkb9F'
      '+3QvwsPDf7OsrOwbLS0tMfSztPw1NjYGHDly5JHAwMD76Gfbkfj4+D+sra39EX1PWv+qq6u/HxMT8wD9'
      '3HsRGhr6+sLCwsdl//+cP+9/Fy9eDM7Ozv5IUFDQr9F3rxvBwcGva2trS93Z2dnY39/f/z+TsbOzs9nZ'
      '2Xk8JCTk12nfKCEhIfcj0W5vb6/L9nV/f39vfn7+ekZGxgfo59uN2NjYd4yOjjbs7e3t0Pekld3d3e3+'
      '/v4KLT8kgYGBr25oaPifra2tFdn/Pwfv4L0uLy/fKCgo+Dx9/7qRlpb2vuXl5Rn6MGZibW3t1tGjRx+l'
      'faOkpqa+d2VlZZa2Pyj4j7py5UpyYGDgr9IYdqK6uvpZJBH6fg7K9vb2Rn5+/mfp51Mw68IPAG3vwAvG'
      '9/Xr1130/evGmTNnfri3t7dLH8RMYHbS0NDwC9o3Snp6+sNra2sLtL0Mc3NzPTExMb9HY9iFkJCQ1w8O'
      'DtbQ9yIDxl9paenXaQxKUVHRl5GwaHsHfkZGRuro+9cF6OuhoaFa+gBm5OWXX27Ceg/to5Lo6OgHZmdn'
      'u2lbGSDptPx6W5X09PS/5JhVAnwOPo/GUII1imvXrp10ZJhv8FkS4hxI/mZ9ff12ZmbmB2kflUA+Xbly'
      'JYVjIOMz2tvb0+26QF1TU/Mc1wx6aGjoTGhoqNc1PUixhYWFIdrWQR98loTOnj37n1wDyd8gKWDRkvaR'
      'kpeX96mtra1V2l6GGzdudGpZULUawcHBr33ppZdK6PuQAeOvpqbmhzQGpaSk5Cs7OztbtL2DPvgkCYWG'
      'hr5heHjYElLMw/j4eFNYWJiaJPvdmZmZa7StDJubm8snTpz4GI1hdZKTk//kzp074/R9yLCysjKTlpb2'
      'fhpDSVBQ0KuvXbuWwzGDddCGT5IQtphXV1fnaHAzIyTZh2hflQQEBNx3+fLlRI4Bjc944YUXogICAn6F'
      'xrEyLpfrid3dXelteSUDAwNVascr4uPj/2hhYWGYtnXQD58koXPnzv3EKlLMg9gl+1+1pJCbm/sJLkk2'
      'PT3dHhkZ+VYaw6pAivX19ZVxJHGcL6qpqfkBjUEpKSn56u7uriPFfIjuSQhSbHR0tJ4GtgLj4+Mt4eHh'
      'b6Z9VhIdHf02TkmWk5PzcRrDqkCKLS4uTtD3IMPS0tJ0amrqX9AYSjy7YrStg77onoSwK7a6ujpPA1sB'
      'SLLjx49/mPZZCXa0Ll26lMDxa66QZLbYJXO5XN9hlmL30xhKEhISHnSkmO/RPQm53e4nrSbFPECSNTY2'
      'BqlJspMnTz7GKMmuRkVF/Q6NYTVCQkJe19fXV0r7LwPGX3V19TM0BgWHGHE1h7Z30BddkxDuivX397to'
      'UCsxMTHRgku5tO9KkDRmZmZepG1lgCTDOhONYTVSUlL+bGlpaZL2XwYhxf6cxlAipFgubeugP7omoeTk'
      'ZAykKRrUSqyurt7MyMj4K9p3JZBkuDXMJcnwWVY/uIgZNMddMXE3qRIzKxpDSWxs7Nvn5uZ6aXsH/dE1'
      'Cbnd7qcPc+vZDGCqf+7cuf+ifafk5uZ+kkuSYaHbypIMCaO/v7+c9lsGIcWepTEoWLvE5WTa3kF/dEtC'
      'WASEbQINaEVGRkbO424cfQdKYEVx8+bNPtpWBiQzrDPRGFYB0olrBi1cD/6axqBA/i0vL0/T9g76gpkq'
      'jmHQ/w8WsB1ql//UtbW1eTXPH/jTdHR0HOWSZNhxs6okq6qqeoZrV2xkZKQ+LCzsN2gMCs4k4dwXdjw5'
      '/o8c1MEsdX5+vj8nJ+cf6f8HC5gCc0kx/PJ3dXWdqq+v/znXHxLC+vo6i9UGdsm0SLL8/PzP4UY8bS8D'
      'JBnOINEYZgczaGyncyQCDPK6urqf0hj3ArFxNQb/l3S8+Ouvubk5ApdpOd4HwO4f/Hvq6+ufp7F8/VdV'
      'VfV0cnLyn+py5MQzkOgLkAGJrKmpKVzt5vNBCQ4Ofg0GqC9/cbkl2alTpz5JY5idxMTEB7nuiuGqkNoM'
      '1ejg+AcOqOLeG+3fQRGL9C5bXIROS0uDFDv0SwM4MYtdNhqDg4SEhHdyHU7DLpna2gPsPTo6OjJoWxkw'
      'oJqamkLVziiZjdLS0q9x7IoBLHiq/TCYAfyoDw8Pn6P9Oyh4r2VlZd+kn29JampqIMVYDigic+O8EY3B'
      'AeeNaUiy8+fP/0wtKZw+ffozXJJscnLyUkRExFtoDLMSFBT0mu7u7jzaTxn29vb2zp49+x80hhnBrH1g'
      'YMBN+3hQIMXy8vL+iX6+5cAt5cHBwTMcX2wkMvgQ0RicFBcXs3nHwIhdzXERNq1zc3Mv0bYybGxsLGZl'
      'ZX2ExjAriYmJD92+fXuU9lOGlZWVuSNHjnh1UDQLThI6IOnp6e/j0K9AixXnYYEk4xr42CU7duzY39IY'
      'SrCj1dbWls6RpDH7unjxYoja7MssQCpw3GDHu4V84V5H9BdOEjognGb2Q0NDZ9XO3xwWcTCO5TwTkkJ9'
      'fb2qCX5+fj6nJLtsBXuPoKCg1/b09BTQ/skgZtCWkGLASUIHAJoeB49o52XAQEJCozH0wOVyfZdrMVSY'
      '4L+RxlCCAnyooEHbygBJlp2d/VEaw2wkJSXBQfFl2j8ZrCTFgJOEDoAYSCzbq5BiqFNGY+gBdt+4nls4'
      'LqpJMlYTfJwlMbskKy8v/zbXD4GYQVtCigEnCR2AioqKf+MYSPhiYSCp+b9wgd233t7eYvocMuDZz5w5'
      '8+80BgWDYWtra422l2FqaqrNzGc/hJl9MUdSFjNoy0gx4CQhjUDTYyDRjssgqiI8R2PoCVcCBSjUp+Zl'
      'DEk2OzvbRdvKIEzwTSvJkpKS/nhxcZFlJopNEStJMeAkIY3g+DXnQPKVFPOALwKXJEN9bbXn90gy2lYG'
      'zCDMbIJfUVEBKcZych0FNvXezPA1ThLSiLDiZJlJaLHi5AaL6r29vUX0WWQQkkBVkhUWFj7O5eQ3NTUF'
      'E3zTSTJPXTEOKSZ2J583azK+F04S0gDWVDirImjxf9GDioqKbzH+IqseL0Clz1u3bg3StjIISWY6E3xh'
      'Zs8yA4Vth9o5LTPiJCENpKSkQIqxVEWAlFGriqAXSUlJDzFuE6setIS9R2dnZzZtK4OQZJG63EjWEcyg'
      'udwWcDwiLCzM6/EIM+IkIQ1UVlbCipNlIAkrTq+LunqB/2xIMqYZnaYrJ0VFRV/kOCUMcHDRTHfJkIS5'
      '7oqJu3v/TWNYAScJqQBNDzN7ri9udXX192kMX4KrA1x3yVD6Wk2SxcXF/T6XJIMcyczM/CCNYVRQ7ZSr'
      '7/CGOnbs2KM0hhVwkpAKQoqxVEUQpvF+9X/BLhnXXTLRn0doDCW4yd/Z2ZnFkcQxG7hw4YJqVVijUFRU'
      '9GWuhfnR0dELVrDtuBtOElLB7XY/xaXpcQvd3wMJM7vu7u7THEkBM7va2tof0xiUwsLCL25vb2/Q9jKM'
      'j4+/oHaT3wiIEjusNio0hlVwkpAXuC9/arFI9QXiNjfLcQMYa2mQZH/A5bi4vr5+xwySLD4+/p1cUkyr'
      'mb1ZcZKQFzirIqBUtFr9Ll+Rmpr6Xi6Tfi39giS7evXqMaZZwf6FCxcCaAyjUVJS8jWutbfR0dH60NDQ'
      'N9AYVsFJQl5gnjGcDwsLM8RACg4Ovh+7dPQZZdA6wysoKPg8l72H0SUZpBin5K2rq/sJjWElnCR0D4QV'
      'J9tA0vJF9SVVVVXf4/JFwi+12loXTPAZHRfvHD9+/EM0hlHgNJIzwmaG3jhJ6B4kJia+a2FhYYR2VAYt'
      'pZR9TWpq6nu4pCbuwkHi0RhKuE3wjbxLxmxmr5rgzY6ThO5BWVnZN7g0vbDiNIQU84BFd5jsM830dlAS'
      'm8agcJrgj4+Pt0RERLyZxvA3kGJdXV1sBxRra2sNNYPWAycJ3QW8FFhxMn1BsY39IxrDCOAkONfxAxzo'
      'VLuUi10yrhJE2CUzogl+QkLCu7ikGGSnGXYCD4uThO4CCtTdvn17jHZSBtyxOnLkyMM0hhFAfXIuSba0'
      'tDStdicOs4Senp58juRuVBP80tLSr3NdU5mYmGg14myPGycJ3YXy8vJ/5dL0Wm6b+wu4A+AcFEdSEO4A'
      'qldSIHO5vqTCBN8w9h6ezQz6nDLg/6SxsTHIaElWD5wkRMBA4qyK4Csze1nE5VyWhDswMFCtJsnEgj+L'
      'JBMm+IaRZEKKsWxmoG9G3gHkxElCBM6qCCgVjTplNIaRgAk+l98N+osS2TSGEgy4rq6uUxyzL89sgcbw'
      'FwUFBf/MtfA+MTHREh4e/iYaw4o4SYjA6cUsrDj9YtuhFUgyTu9sLYZtJSUlX2W82GmILWwcQWA8Fb5n'
      'FykGnCSkwFMVgXZOBo8VJ41hRFwuF0vixRcQJvhqiVfcqxqi7WUwyr0qHMacn5/vp88ngyirZAspBpwk'
      'pIDTzF4MJFNsr0KCcvVbiyQTN8xP0rYyINnX1dX9lMbwNYWFhV/Y2dnhcgpoDg8Pt/yumAcnCSmoqKh4'
      'gmNGAMbGxi4a+X6TEhxcxAyG9kEGreWMOL12xsbGGv0pyeCgePXq1UwuKYZS23aRYsBJQgL8OnNZn5qx'
      'KgJ28fDctC8yDA4OngkJCfF6LIHTBF9Isr+hMXwFDmHeunVrgD6XDMJB0XJm9t5wkpBAfClYBpKoimAq'
      'K8709PT342Al7YsMuEumxQT/xRdfPEHbyiAkmd9Mv+CjzTWrg5m9WWbQXDhJSFBcXMwtD0w1kLCYjN08'
      '2hcZxC7ZD2gMipBkLAcX8c7Dw8N9XolCVBTJos8jg5hB/9xMM2gOnCQkBpJjxflLSfYcl70HCv5ht5HG'
      'UBIfHw8ZwybJ/CFj4uLi2GSllc3sveEkISHFuE7xwmnQn+sThwEHK7G7RfskA0pOY7eRxlDCbYLf0NDw'
      'CxpDb4qKir7EPIP22wK7v3CS0CtSjEUWmLkqAuqhoUQ17ZMM2GV0uVxP0BgU2KBy7Uj6ej2F2cx+v7m5'
      'OZzGsAO2T0KBgYG/HEi0QzIY5czKYcBaDoe9B75UKJ2N7X8aQwlmS5g10fYyQM5kZmb+HY2hF5x1xUSZ'
      '63+gMeyA7ZMQrDi5pNja2hqkmN9P7x4G2HGgVDXtmwyo14a6bTSGEu5T6r40wS8uLma7fjI9Pd0eGRn5'
      'VhrDDtg+CZWUlPwL10CCFafRHBQPCm7Bc5ngY5Hb7XY/SWNQysvLv81l7+ErE3zmzYz9pqamcLvtinmw'
      'dRKCbQfXjW4jmtnLUlVV9QyHJAPwK1LbJRPOBSwmcrgu44uNgZiYmAfm5uZ6aHwZhCXJx2gMu2DrJJSQ'
      'kPAglxTTUn/LLKSkpLDVW1taWprUsEsGD6d82lYGSDJfeDhhsG9tba3R+DJMTU1dMZI5m6+xdRLiNLOH'
      'FadV/F88Jvi0jzJgRlVZWfkUjUEpKytjc7McHh6GhYrXayOHITAw8L62trY0jhm0kGKhdpViwLZJCL++'
      'vb29hUwDyZB+x4fB7XY/xXVwEZJMzXFRuBKySDLh6/0IjcGFkGJsNdSM5A7pD2ybhGBmz7kOkZWV9fc0'
      'hplJT09/GBKT9lUGSDu1umTcVUtra2t/TGNwcfr06U8zOijawszeG7ZNQnD3293dZVl8hRVnRETEW2gM'
      'M4OS1XAtpH2VAe8Zi900BkWY4LNIMjy7HrtkSJYo4siRLPEZdnJQvBe2TEKw4mxvb+eqBoqzKZqqgeJl'
      '46Kov//Udqs8oAb63t4ei70Htv01SjIWo/itra1VzIZiY2PfTvsv+4fFYxQGwHkwGk8G7IplZWV9mL4H'
      'u2HLJAQrzps3b7JYcYoCdapWnKg9hjUoXC3w9x8WnbOzsz+qljix24cS1rTPMoi6ZO+hMZRwSjIAp0NY'
      'rtL+y/7duHGjE8mNxpFFVJG1xGbGYbBlEkJVBEYrTtXDcXFxce+YnJy8xPXlOix4jtnZ2R7MPOizKsEd'
      'uOHh4TraXgYcRsQOGI1BQR13rsOjRsZuZvbesF0SYrbi3IcUozEo4oIsS9LjAus0Wi6YQtJw7JLhXeEs'
      'EGY7NIYS1CXjKqNsZIQUs9Rmhiy2S0Kw4mSWYl7N7DlvWnOjxfMHW91cjovYgkeSoTGUeKrC0rZWY2Zm'
      '5lp0dPTbaP/tiO2SUGFh4ePb29sssxJRFcGrFMMFWa6b1twsLi5OJCcnv5s+sxLcheNyXMTOlxZJ5na7'
      'n+a6NmJE8IPU2toah0OPtO92xFZJSPgaZ3PMSjy7YjQGxchrHJBklZWV36XPTME1CA5JBoQk8zr7QlVY'
      'XPegba0CbDtyc3M/QfttV2yVhDirIgg7Ua/eNZBiXV1deRxJTy/6+vpKIYHosyvhNMGHJMOFVRpDiZBk'
      '5bStVZienu6Iior6bdpvu2KrJMRcFQF1xbxurwqvIpZzL3ohPH+8bp3DcXFoaOgsRzLFLhmsO2gMCs7j'
      'WFGS4R22tLTEOFLsFWyThOBnzCjFsCsWqLa9CinGdQJYL/B8uCdGn53CKclgYqa2IC6q4U7QtmZnc3Nz'
      'JScn5+O0v3bGNklImNmz1D8XVpxeBxIuyHZ3d+fRtkYEhxfVbFghybhM8MWCuFd7DyQpSEWOHw0jASlm'
      'Z9uOu2GbJFRcXPwVLik2NTXVpmbFmZiY+JBZzruIC6ZeJRmuLcAig7aVQasJPv6NlSSZkGLRajNou2GL'
      'JOSx4qQPLQMGUnNzc0RAQIBXTS/8cVi8ivQGX/Sqqqrv0T4owRcHJXU4SkXjHcIEX4Mke/fi4iKLCb4R'
      'wAw6JyfHlmb23rBFEoqOjob/Sy99aBk2NzeXTpw44dWKExU8urq6cmlbo4KkgEGgtkuGShbYFaTtZdBy'
      'RkmY4JfQtmZlamqqPSoqyusM2o7YIgmdOnXqU1xWnJOTk5fVbDvEBdk+2tbILC8vT6vtkuFgJgr00bYy'
      'YJHb5XJ9h8agVFRUsJng+xPFDNqRYgRbJKHLly8ncixw4jOamprC1AZSXl4em+mVr0BSKC8v/xbtC6Wu'
      'ru5nHJIMYLYIWxUaQwmnCb4/sbuZvTdskYR6e3uL6APLsLGxsZSdna166bCmpuY5ri+qr0CCra6ufpb2'
      'hYJKFlySbGxsrAFnkGgMJZBkPT09BbSt2YCZfUREhLMrdhdwqJejzJShk1B9ff3zhz3jgi8pPGW0WHHC'
      'qweWr/QzjAwWTU+ePPkY7QsFBvK4YHrYmSX+P7BTpOXQnpBkpt0lQ1+xqK82g7YrGAMw+z/sdxRFOzMy'
      'Mj5AP98QoITNYUsNQ15puXwJ8EXlKmHjK0ZGRs6HhYW9kfblbuTm5j62vr5+h37GQZifn7+udn3Dw9Gj'
      'Rx81W1JXgrGHMUj75fAK8DSH8R19dweho6PjKM7n0c82Av8PixzBPiYjLTkAAAAASUVORK5CYII=';
}
