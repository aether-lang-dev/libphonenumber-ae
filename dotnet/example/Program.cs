// A short tour of the .NET binding (ABI v2). Run it with the engine built:
//
//   aeb core/.build.ae
//   cd dotnet && LIBPHONENUMBER_AE_LIB=../target/build/core/lib/libphonenumber_ae.so \
//       dotnet run --project example/Example.csproj

using System;

using PhoneNumbers;

Console.WriteLine($"engine: {PhoneNumber.NativeLibraryPath} (ABI v{PhoneNumber.AbiVersion})");

Console.WriteLine("country code US: " + PhoneNumber.CountryCode("US"));            // 1
Console.WriteLine("is valid:        " + PhoneNumber.IsValidNumber("US", "+1 201 555 0123")); // True

// parse into a ParsedNumber and read its fields on demand
var num = PhoneNumber.Parse("+1 650 253 0000", "US");
Console.WriteLine("parsed national: " + num.NationalNumber);   // 6502530000
Console.WriteLine("parsed cc:       " + num.CountryCode);      // 1
Console.WriteLine("parsed region:   " + num.RegionCode);       // US

Console.WriteLine("national fmt:    " + PhoneNumber.Format("US", "2015550123", FormatStyle.National));      // (201) 555-0123
Console.WriteLine("intl fmt:        " + PhoneNumber.Format("US", "2015550123", FormatStyle.International));  // +1 201-555-0123
Console.WriteLine("e164 fmt:        " + PhoneNumber.Format("US", "2015550123", FormatStyle.E164));          // +12015550123
Console.WriteLine("rfc3966 fmt:     " + PhoneNumber.Format("US", "2015550123", FormatStyle.Rfc3966));       // tel:+1-201-555-0123

Console.WriteLine("number type:     " + PhoneNumber.NumberType("US", "2015550123")); // FixedLine

// format as it is typed, digit by digit
var ayt = new AsYouTypeFormatter("US");
string shown = "";
foreach (var c in "6502530000") shown = ayt.InputDigit(c);
Console.WriteLine("as you type:     " + shown);   // (650) 253-0000

// find numbers in free text
foreach (var m in PhoneNumber.FindNumbers("call 201-555-0123 or +1 202 555 0199 today", "US"))
    Console.WriteLine($"found:           {m.Raw} [{m.Start}..{m.End}]");

var regs = PhoneNumber.Regions();
Console.WriteLine($"regions:         {regs.Count} known (first: {regs[0]})");
