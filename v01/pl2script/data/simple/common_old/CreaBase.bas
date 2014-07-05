Attribute VB_Name = "CreaBase"
Option Compare Database
Option Explicit

Const Meta_file_name = "Schema_meta"
Const sw = 100
Dim BaseName As String


Public Function StoreCaptions()
   Dim t As TableDef, rs As Recordset, c As String
   Set rs = CurrentDb.OpenRecordset("SELECT LOOK_BASE FROM " & Meta_file_name & " WHERE TABLE_NAME='-' AND FIELD_NAME ='-';")
   BaseName = "SYS"
   If Not IsNull(rs!Look_Base) Then
      BaseName = rs!Look_Base
   Else
      MsgBox ("Не найдено описание базы в наборе данных " & Meta_file_name & "  в поле [Look_Base]")
      Exit Function
   End If
   
   MsgBox ("Текущий пользователь: " & CurrentUser)
   
   Set rs = CurrentDb.OpenRecordset(Meta_file_name)
   While Not rs.EOF
      If rs!Field_Pos > 0 Then
         c = ""
         If Not IsNull(rs!Caption) Then c = rs!Caption
       
         StoreFieldCaption rs!Table_Name, rs!Field_Name, c
         If Not IsNull(rs!Look_Table) Then
            StoreTableCaption rs!Look_Table, rs!Caption, IIf(IsNull(rs!Look_Base), "", rs!Look_Base)
         End If
      Else
         If rs!Field_Type = "T" Then
            c = ""
            If Not IsNull(rs!Caption) Then c = rs!Caption
            StoreTableCaption rs!Table_Name, rs!Caption
         End If
      End If
      rs.MoveNext
   Wend
   CreateReferences
   Application.Echo True, "Готово"
End Function

Private Sub StoreFieldCaption(t As String, f As String, c As String, Optional b As String = "")
   Dim TableName As String
   Dim p As Property, td As TableDef
   On Error Resume Next
   TableName = t
   If b = "" Then b = BaseName
   If CurrentDb.TableDefs(TableName) Is Nothing Then
     If b <> BaseName Then
       TableName = t + "@" + b
     End If
   End If
   If Not CurrentDb.TableDefs(TableName) Is Nothing Then
     On Error GoTo exists
     Set p = CurrentDb.TableDefs(TableName).Fields(f).CreateProperty("CAPTION", dbText, c, True)
     CurrentDb.TableDefs(TableName).Fields(f).Properties.Append p
     GoTo existsNoError:
exists:
     Debug.Print "Ошибка создания свойства поля" + Chr(13) + t & " " & f & " " & c + Chr(13)
     Resume Next
existsNoError:
     On Error GoTo 0
     On Error GoTo done
     CurrentDb.TableDefs(TableName).Fields(f).Properties("CAPTION").Value = c
     GoTo DoneNoError
done:
     Debug.Print "Ошибка занесения описания поля" + Chr(13) + t + " " + f + " " + c + Chr(13)
     Resume Next
   End If
DoneNoError:
   On Error GoTo 0
End Sub

Private Function GetDescript(b As String, t As String, f As String) As Recordset
  Dim p1 As Integer, path As String, sql As String
  Dim td As TableDef, rs As Recordset
  If b = "" Then
    p1 = InStr(t, "@")
    If p1 > 0 Then
      b = Mid(t, p1 + 1, Len(t) - p1)
      t = Mid(t, 1, p1 - 1)
    Else
      b = CurrentDb.OpenRecordset("SELECT LOOK_BASE FROM " & Meta_file_name & " WHERE TABLE_NAME='-' AND FIELD_NAME='-'")!Look_Base
    End If
  End If
  If b = "" Then b = BaseName
  Set rs = CurrentDb.OpenRecordset("SELECT PATH FROM BASES WHERE BASE='" + b + "';")
  If Not IsNull(rs!path) Then path = rs!path
  If Len(path) > 0 Then
     If Mid(path, Len(path), 1) <> "\" Then path = path + "\"
  End If
  sql = "SELECT * FROM " & Meta_file_name
  On Error Resume Next
  Set rs = CurrentDb.OpenRecordset(sql + " WHERE TABLE_NAME='" + t + "' AND FIELD_NAME='" + f + "';")
  Set GetDescript = rs
  On Error GoTo 0
End Function

Private Sub StoreTableCaption(t As String, c As String, Optional b As String = "")
   Dim rs As Recordset, db As Database
   Dim path As String, TableName As String
   Dim p As Property, td As TableDef, newTd As TableDef
   On Error Resume Next
   If b = "" Then b = BaseName
   TableName = t
   Application.Echo True, "Занесение описания " + t
   Set td = CurrentDb.TableDefs(TableName)
   If Not td Is Nothing Then GoTo TableExists
   If b <> BaseName Then
     TableName = t + "@" + b
     Set td = CurrentDb.TableDefs(TableName)
     If Not td Is Nothing Then GoTo TableExists
   End If
   On Error GoTo 0
CreateTbl:
     Application.Echo True, "Импорт " + TableName
    Set rs = CurrentDb.OpenRecordset("SELECT * FROM BASES WHERE BASE=""" + b + """")
    If Not IsNull(rs!path) Then path = rs!path
    If path = "" Then
       Set db = Application.CurrentDb
       Set newTd = db.CreateTableDef(TableName)
       CreateTableStructure newTd, TableName
    Else
       If Mid(path, Len(path), 1) <> "\" Then path = path + "\"
       Set newTd = CurrentDb.CreateTableDef(TableName + "_TEMP") ' , dbAttachedTable
       newTd.Connect = "FoxPro 2.6;DATABASE=" + path + "DBFCDX\"
       newTd.SourceTableName = t
       newTd.name = TableName
   End If
   On Error GoTo done
     
   On Error Resume Next
    'CurrentDb.TableDefs.Delete (t)
    CurrentDb.TableDefs.Append newTd
    DBEngine.Idle dbRefreshCache
    CurrentDb.TableDefs.Refresh
TableExists:
    
    On Error Resume Next
    
    Set p = CurrentDb.TableDefs(TableName).CreateProperty("DESCRIPTION", dbText, c, True)
    CurrentDb.TableDefs(TableName).Properties.Append p
    CurrentDb.TableDefs(TableName).Properties.Refresh
    GoTo existsNoError:
exists:
     Debug.Print "Ошибка создания свойства таблицы" + Chr(13) + t + " " + c + Chr(13)
     Resume Next
existsNoError:
     On Error Resume Next
     CurrentDb.TableDefs(TableName).Properties("DESCRIPTION").Value = c
     DBEngine.Idle dbRefreshCache
     CurrentDb.TableDefs(TableName).Properties.Refresh
     GoTo DoneNoError
done:
     Debug.Print "Ошибка занесения описания таблицы" + Chr(13) + t + " " + c + Chr(13)
     Resume Next
DoneNoError:
     On Error GoTo 0
End Sub

' Создание связей и описание типа ввода полей
Private Sub CreateReferences()
    Dim rs As Recordset
    Dim fld As Field, fld0 As Field, rel As Relation
    Dim tbl As TableDef, td As TableDef, qdf As QueryDef
    Dim flds As Fields
    Dim p As Property
    Dim s As Container
    Dim i As Integer
    Dim db As Database
    Dim SelStr As String
    Dim shab As String, st As String, tt As String, cc As Integer
    Dim RelTableName As String
    Application.Echo True, "Настройка свойств"
    Set db = CurrentDb
    For Each rel In db.Relations
      db.Relations.Delete rel.name
    Next rel
    ' Возвращает переменную типа Database,
    ' указывающую на текущую базу данных.
    
    For Each tbl In db.TableDefs
      Application.Echo True, "Изменение свойств полей " + tbl.name
      If tbl.name <> UCase(tbl.name) Then tbl.name = UCase(tbl.name)
        If InStr(tbl.name, "@") = 0 Then 'IF tbl.Name = "USLTEL"
        For Each fld In tbl.Fields
          cc = 0
          Application.Echo True, "Поле " + tbl.name + " . " + fld.name
          If fld.name <> UCase(fld.name) Then fld.name = UCase(fld.name)
          On Error GoTo NoRecord
          Set rs = GetDescript("", tbl.name, fld.name)
          If Not rs Is Nothing Then
            If Not rs.EOF Then
              On Error Resume Next
              Set p = fld.CreateProperty("Description", 10, rs!Comment, True)
              fld.Properties.Append p
              On Error GoTo 0
              cc = 0
              If Not IsNull(rs!Look_Table) Then
                RelTableName = rs!Look_Table
                
                On Error Resume Next
                Set td = Nothing
                Set td = db.TableDefs(RelTableName)
                
                If td Is Nothing Then
                  RelTableName = rs!Look_Table + "@" + rs!Look_Base
                  Set td = db.TableDefs(RelTableName)
                End If
                On Error GoTo 0
                If Not td Is Nothing Then
                   RelTableName = td.name
                   If Not Nz(rs!Auto_Inc, False) Then
                      Set rel = db.CreateRelation(tbl.name + "&" + rs!Look_Table, tbl.name, RelTableName) ' , &H1000002
                      Set fld0 = rel.CreateField(fld.name)
                      fld0.ForeignName = rs!Look_Field
                      rel.Fields.Append fld0
                      rel.Attributes = &H1000002
                      ' On Error Resume Next
                      db.Relations.Append rel
                   End If
                   On Error GoTo 0
                   
                   Set fld0 = Nothing
                   Set rel = Nothing
                  
                   On Error Resume Next
                   fld.Properties.Delete "DisplayControl"
                   On Error GoTo 0
                   Set p = fld.CreateProperty("DisplayControl", 3, 111, True)
                   fld.Properties.Append p
                   On Error Resume Next
                   fld.Properties.Delete "RowSourceType"
                   On Error GoTo 0
                   Set p = fld.CreateProperty("RowSourceType", 10, "Table/Query", True)
                   fld.Properties.Append p
                   On Error Resume Next
                   fld.Properties.Delete "RowSource"
                   On Error GoTo 0
                   SelStr = rs!Look_Table
                   If Nz(rs!Look_Field) <> "" Then
                      SelStr = "SELECT "
                      SelStr = SelStr & rs!Look_Field
                      cc = 1
                      If Nz(rs!Disp_Field) <> "" Then
                         SelStr = SelStr & ", " & rs!Disp_Field
                         cc = 2
                      End If
                      SelStr = SelStr & " FROM " & rs!Look_Table
                      If Nz(rs!Disp_Field) <> "" Then
                         SelStr = SelStr & " ORDER BY " & rs!Disp_Field
                      End If
                      SelStr = SelStr & ";"
                   End If
                   Set p = fld.CreateProperty("RowSource", 12, SelStr, True)
                   fld.Properties.Append p
                   On Error Resume Next
                   fld.Properties.Delete "BoundColumn"
                   Set p = fld.CreateProperty("BoundColumn", 3, 1, True)
                   fld.Properties.Append p
                   On Error Resume Next
                   fld.Properties.Delete "ColumnCount"
                   fld.Properties.Delete "ColumnHeads"
                   fld.Properties.Delete "ColumnWidths"
                  
                   On Error GoTo 0
                   If Not CurrentDb.TableDefs(rs!Look_Table) Is Nothing Then
                      Set flds = db.TableDefs(rs!Look_Table).Fields
                   Else
                      If Not db.TableDefs(rs!Look_Table + "@" + rs!Look_Base) Is Nothing Then
                         Set flds = db.TableDefs(rs!LookTable).Fields
                      Else
                         If CurrentDb.QueryDefs(rs!Look_Table).name = rs!Look_Table Then
                            Set flds = db.QueryDefs(rs!Look_Table).Fields
                         End If
                      End If
                   End If
                  
                   If flds(0).Type = dbText Then
                      shab = Str$(sw * flds(0).Size)
                   Else
                      shab = "0"
                   End If
                   If cc = 0 Then
                      For cc = 1 To 3
                         If cc >= flds.Count Then Exit For
                         shab = shab + ";" + Str$(sw * flds(cc).Size)
                      Next cc
                   Else
                      If cc = 1 Then
                         shab = "5000"
                      Else
                         shab = "0;5000"
                      End If
                   End If
                   Set p = fld.CreateProperty("ColumnHeads", 1, cc > 2, True)
                   fld.Properties.Append p
                   Set p = fld.CreateProperty("ColumnCount", 3, cc, True)
                   fld.Properties.Append p
                   Set p = fld.CreateProperty("ColumnWidths", 10, shab, True)
                   fld.Properties.Append p
                   On Error Resume Next
                   fld.Properties.Delete "ListRows"
                   On Error GoTo 0
                   Set p = fld.CreateProperty("ListRows", 3, 8, True)
                   fld.Properties.Append p
                   On Error Resume Next
                   fld.Properties.Delete "ListWidth"
                   On Error GoTo 0
                   Set p = fld.CreateProperty("ListWidth", 10, "0", True)
                   fld.Properties.Append p
                   On Error Resume Next
                   fld.Properties.Delete "LimitToList"
                   On Error GoTo 0
                   Set p = fld.CreateProperty("LimitToList", 1, True, True)
                   fld.Properties.Append p
                   Set td = Nothing
                End If
              End If
            End If
          End If
NoRecord:
          On Error GoTo 0
          DBEngine.Idle dbRefreshCache
       Next fld
      End If
    Next tbl
End Sub


' создание структуры по описанию для таблицы td
Public Sub CreateTableStructure(td As TableDef, TableName As String)
   Dim rs As Recordset, fd As Field
   Dim s As String
   Dim ft As Long, fs As Long, ftString As String, attr As Long
   s = "SELECT * FROM " & Meta_file_name & " WHERE [Table_Name]='" & TableName & "' AND (([Field_Pos] > 0) AND ([Field_Pos] < 255)) ORDER BY [Field_Pos];"
   Set rs = CurrentDb.OpenRecordset(s)
   If rs.RecordCount = 0 Then Exit Sub
   rs.MoveFirst
   While Not rs.EOF
      ft = dbText
      fs = 50
      attr = 0
      ftString = rs!Field_Type
      Select Case ftString
         Case "C"
            If rs!Field_Len > 0 Then fs = rs!Field_Len
            Set fd = td.CreateField(rs!Field_Name, ft, fs)
         Case "N"
            If rs!Auto_Inc Then
               ft = 4
               attr = 17
               Set fd = td.CreateField(rs!Field_Name, ft)
               fd.Attributes = attr
            Else
               If rs!Field_Dec = 0 Or IsNull(rs!Field_Dec) Then
                  If rs!Field_Len <= 6 Then
                     Set fd = td.CreateField(rs!Field_Name, dbInteger)
                  Else
                     If rs!Field_Len <= 10 Then
                        Set fd = td.CreateField(rs!Field_Name, dbLong)
                     Else
                        Set fd = td.CreateField(rs!Field_Name, dbDouble)
                     End If
                  End If
               Else
                  Set fd = td.CreateField(rs!Field_Name, dbDouble)
               End If
            End If
         Case "D"
            Set fd = td.CreateField(rs!Field_Name, dbDate)
         Case "L"
            Set fd = td.CreateField(rs!Field_Name, dbBoolean)
         Case Else
            Set fd = td.CreateField(rs!Field_Name, dbText, 50)
      End Select
      td.Fields.Append fd
      rs.MoveNext
   Wend
   CurrentDb.TableDefs.Append td
End Sub
