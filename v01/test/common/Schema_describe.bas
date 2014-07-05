Attribute VB_Name = "Schema_describe"
Option Compare Database
Option Explicit

Const Meta_file_name = "Schema_meta"


Public Function CreateMaket()
   ImportMaketData

End Function


Private Function ImportMaketData()
   ImportTables
End Function

Private Function ImportTables()

   Dim i As Long
   For i = 0 To CurrentDb.TableDefs.Count - 1
      If CurrentDb.TableDefs(i).Attributes = 0 Then
         ImportOneTable CurrentDb.TableDefs(i).name
      End If
   Next i

End Function

Private Function ImportOneTable(name As String)
   Dim td As TableDef, pr As Property
   Dim rs As Recordset, s As String
   
   Set rs = CurrentDb.TableDefs(Meta_file_name).OpenRecordset(dbOpenTable)
   Set td = CurrentDb.TableDefs(name)
   
   rs.Index = "PrimaryKey"
   rs.Seek "=", name, "-"
   If rs.NoMatch Then
      rs.AddNew
      rs!Table_Name = name
      rs!Field_Name = "-"
      rs!Field_Type = "T"
      rs!Field_Pos = 0
      rs.Update
   End If
   rs.Seek "=", name, "-"
   CurrentDb.Execute ("UPDATE " & Meta_file_name & " SET [Field_Pos] = 255 WHERE [Table_Name] = '" & name & "' AND [Field_Name] <> '-';")
   If rs.NoMatch Then
      MsgBox "Нет описания таблицы " & name
   Else
      On Error Resume Next
      For Each pr In td.Properties
         Debug.Print pr.name
      Next pr
      Set pr = td.Properties("Description")
      On Error GoTo 0
      If Not pr Is Nothing Then
         s = pr.Value
      End If
      rs.Edit
      rs!Caption = s
      rs!Comment = s
      rs.Update
   End If
   ImportFields name
End Function

Private Function ImportFields(name As String)
   Dim db As Database, td As TableDef
   Dim flds As Fields, fld As Field
   Dim i As Long
   
   Set db = CurrentDb
   Set td = db.TableDefs(name)
   Set flds = td.Fields
   i = 1
   For Each fld In flds
      ImportOneField name, fld, i
      i = i + 1
   Next fld
End Function

Private Function ImportOneField(name As String, fld As Field, nom As Long)
   Dim rs As Recordset, pr As Property
   Set rs = CurrentDb.TableDefs(Meta_file_name).OpenRecordset
   rs.Index = "PrimaryKey"
   rs.Seek "=", name, fld.name
   If rs.NoMatch Then
      rs.AddNew
      rs!Table_Name = name
      rs!Field_Name = fld.name
      rs.Update
   End If
   rs.Seek "=", name, fld.name
   If rs.NoMatch Then
      MsgBox "Не найдено поле " & name & "." & fld.name
   Else
      rs.Edit
      rs!Field_Pos = nom
      rs!Field_Type_Paradox = fld.Type
      On Error Resume Next
      Set pr = fld.Properties("Caption")
      On Error GoTo 0
      If Not pr Is Nothing Then
        rs!Caption = pr.Value
        rs!Comment = pr.Value
      End If
      rs.Update
   End If
End Function
