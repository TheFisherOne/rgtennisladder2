import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const int softwareVersion=3;

const textInputDecoration = InputDecoration(
    fillColor: Colors.white,
    filled: true,
    enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.cyan, width: 2.0)),
    focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.pink, width: 2.0)));

const double appFontSize=20;
const nameStyle = TextStyle(
    decoration: TextDecoration.none,
    fontSize: appFontSize,
    fontWeight: FontWeight.normal);

const nameBoldStyle = TextStyle(
    decoration: TextDecoration.none,
    fontSize: appFontSize,
    fontWeight: FontWeight.bold);

// NumberFormat plusMinus=NumberFormat("\u25b20;\u25bc0");
NumberFormat plusMinus=NumberFormat("^0;v0");

const courtColors = [
  Colors.lightGreen,
  Colors.lightBlue,
  Colors.grey,
  Colors.amberAccent,
  // Colors.white,
  // Colors.white,
  // Colors.white,
  // Colors.deepPurpleAccent,
  // Colors.brown,
  // Colors.tealAccent
];
final appBackgroundColor=Colors.brown.shade50;
final partnerColor=Colors.blue.shade50;
final appBarColor=Colors.brown.shade400;
const scoreBadDecoration= InputDecoration(fillColor: Colors.red, filled: true);
final scoreGoodDecoration=InputDecoration(fillColor: appBackgroundColor, filled: true);
final scorePartnerDecoration =InputDecoration( fillColor: partnerColor, filled: true);
final scoreBackgroundDecoration= InputDecoration(fillColor: Colors.grey.shade50, filled: true);

// const orderOfCourts1=[1,2,3,4,8,9,10];
// const orderOfCourts2=[8,9,10,1,2,3,4];
// const orderOfCourtsThursday=[8,9,10,4,3];
const orderOfCourtsFull=[8,9,10,1,2,3,4];
const scoreEntryTimeout=120;
