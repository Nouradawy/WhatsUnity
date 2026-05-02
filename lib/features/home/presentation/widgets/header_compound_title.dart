import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

import '../../../auth/presentation/pages/welcome_page.dart';

Widget headerCompoundTitle(context ,isEnabledMultiCompound ,currentSelectedCompoundId ,currentMyCompounds ,authCubit){
  if(isEnabledMultiCompound)
     {
       return DropdownMenu(
         initialSelection: currentSelectedCompoundId?.toString(),
         width: MediaQuery.sizeOf(context).width * 0.55,
         inputDecorationTheme: InputDecorationTheme(
           border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
           labelStyle: GoogleFonts.plusJakartaSans(color: HexColor("#111518"), fontSize: 13, fontWeight: FontWeight.w500),
           constraints: const BoxConstraints(maxHeight: 50),
         ),
         menuStyle: MenuStyle(
           backgroundColor: WidgetStateProperty.all(Colors.white),
           fixedSize: WidgetStateProperty.all<Size>(Size(MediaQuery.sizeOf(context).width * 0.55, double.infinity)),
           elevation: WidgetStateProperty.all(0.5),
           shape: WidgetStateProperty.all(
             RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(5), // adjust radius
               // optional border
             ),
           ),
         ),

         dropdownMenuEntries:
         (currentMyCompounds.entries.toList().reversed).map((entry) {
           String key = entry.key;
           String value = entry.value;
           return DropdownMenuEntry<String>(leadingIcon: key == '0' ? Icon(Icons.add) : null, value: key, label: value.toString());
         }).toList(),
         onSelected: (selectedKey) async {
           if (selectedKey == '0') {
             Navigator.push(context, MaterialPageRoute(builder: (context) => JoinCommunity()));
           } else {
             final newCompoundId = selectedKey.toString();
             authCubit.fetchCompoundMembers(newCompoundId);
             await authCubit.selectCompound(
               compoundId: newCompoundId,
               compoundName: currentMyCompounds[selectedKey]!,
               atWelcome: false,
             );
           }
         },
       );
     } else {
       return Text(
    // Safely handle the case where currentMyCompounds might be empty
    currentMyCompounds.isNotEmpty ? currentMyCompounds.values.last.toString() : 'Select Community',
    style: GoogleFonts.plusJakartaSans(color: HexColor("#111518"), fontSize: 17, fontWeight: FontWeight.w500),
  );}
}