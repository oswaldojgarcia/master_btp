class zog_cl_data_file_upload definition
public
final
create public .
  public section.
    interfaces if_http_service_extension .
  protected section.
  private section.
    data: tablename type string.
    data: filename type string.
    data: fileext type string.
    data: dataoption type string.
    data: filedata type string.
    methods: get_input_field_value importing name         type string
                                             dataref      type data
                                   returning value(value) type string. methods: get_html returning value(ui_html) type string.
endclass.



class zog_cl_data_file_upload implementation.

  method if_http_service_extension~handle_request.
    case request->get_method( ).
      when conv string( if_web_http_client=>get ).
        data(sap_table_request) = request->get_header_field( 'sap-table-request' ).
        if sap_table_request is initial.
          response->set_text( get_html( ) ).
        endif.
*        else.
*          data(name_filter) = xco_cp_abap_repository=>object_name->get_filter(
*          xco_cp_abap_sql=>constraint->contains_pattern( to_upper( sap_table_request ) && '%' ) ).
*          data(objects) = xco_cp_abap_repository=>objects->tabl->where( value #(
*          ( name_filter ) ) )->in( xco_cp_abap=>repository )->get( ).
*          data(res) = `[`.
*          loop at objects into data(object).
*            res &&= |\{ "TABLE_NAME": "{ object->name }" \}|.
*            if sy-tabix ne lines( objects ).
*              res &&= `,`.
*            endif.
*          endloop.
*          res &&= `]`.
*          response->set_text( res ).
*        endif.
      when conv string( if_web_http_client=>post ).
* the request comes in with metadata around the actual file data,
* extract the filename and fileext from this metadata as well as the raw file data.
        split request->get_text( ) at cl_abap_char_utilities=>cr_lf into table data(content).
        read table content reference into data(content_item) index 2.
        if sy-subrc = 0.
          split content_item->* at ';' into table data(content_dis).
          read table content_dis reference into data(content_dis_item) index 3.
          if sy-subrc = 0.
            split content_dis_item->* at '=' into data(fn) filename.
            replace all occurrences of '"' in filename with space.
            condense filename no-gaps.
            split filename at '.' into filename fileext.
          endif.
        endif.
        delete content from 1 to 4. " Get rid of the first 4 lines
        delete content from ( lines( content ) - 8 ) to lines( content ). " get rid of the last 9 lines
        loop at content reference into content_item. " put it all back together again humpdy dumpdy....
          filedata = filedata && content_item->*.
        endloop.
* Unpack input field values such as tablename, dataoption, etc.
        data(ui_data) = request->get_form_field( 'filetoupload-data' ).
        data(ui_dataref) = /ui2/cl_json=>generate( json = ui_data ).
        if ui_dataref is bound.
          assign ui_dataref->* to field-symbol(<ui_dataref>).
          tablename = me->get_input_field_value( name = 'TABLENAME' dataref = <ui_dataref> ).
          dataoption = me->get_input_field_value( name = 'DATAOPTION' dataref = <ui_dataref> ).
        endif.
* Check table name is valid.
        if
*        xco_cp_abap_repository=>object->tabl->database_table->for(
*        iv_name = conv #( tablename ) )->exists( ) = abap_false
*        or
        tablename is initial.
          response->set_status( i_code   = if_web_http_status=>bad_request
                                i_reason = |Table name { tablename } not valid or does not exist| ).
          response->set_text( |Table name { tablename } not valid or does not exist| ).
          return.
        endif.
* Check file extension is valid, only json today.
        if fileext <> 'json'.
          response->set_status( i_code   = if_web_http_status=>bad_request
                                i_reason = 'File type not supported' ).
          response->set_text( 'File type not supported' ).
          return.
        endif.
* Load the data to the table via dynamic internal table
        data: dynamic_table type ref to data.
        field-symbols: <table_structure> type table.
        try.
            create data dynamic_table type table of (tablename).
            assign dynamic_table->* to <table_structure>.
          catch cx_sy_create_data_error into data(cd_exception).
            response->set_status( i_code   = if_web_http_status=>bad_request
                                  i_reason = cd_exception->get_text( ) ).
            response->set_text( cd_exception->get_text( ) ).
            return.
        endtry.
        /ui2/cl_json=>deserialize( exporting json        = filedata
                                             pretty_name = /ui2/cl_json=>pretty_mode-none
                                   changing  data        = <table_structure> ).
        if dataoption = '1'. "if replace, delete the data from the table first
          delete from (tablename).
        endif.
        try.
            insert (tablename) from table @<table_structure>.
            if sy-subrc = 0.
              response->set_status( i_code   = if_web_http_status=>ok
                                    i_reason = 'Table updated successfully' ).
              response->set_text( 'Table updated successfully' ).
            endif.
          catch cx_sy_open_sql_db into data(db_exception).
            response->set_status( i_code   = if_web_http_status=>bad_request
                                  i_reason = db_exception->get_text( ) ).
            response->set_text( db_exception->get_text( ) ).
            return.
        endtry.
    endcase.
  endmethod.
  method get_input_field_value.
    field-symbols: <value> type data,
                   <field> type any.
    assign component name of structure dataref to <field>.
    if <field> is assigned.
      assign <field>->* to <value>.
      value = condense( <value> ).
    endif.
  endmethod.
  method get_html. ui_html =
    |<!DOCTYPE HTML> \n| &&
    |<html> \n| &&
    |<head> \n| &&
    | <meta http-equiv="X-UA-Compatible" content="IE=edge"> \n| &&
    | <meta http-equiv='Content-Type' content='text/html;charset=UTF-8' /> \n| &&
    | <title>ABAP File Uploader</title> \n| &&
    | <script id="sap-ui-bootstrap" src="https://sapui5.hana.ondemand.com/resources/sap-ui-core.js" \n| &&
    | data-sap-ui-theme="sap_fiori_3_dark" data-sap-ui-xx-bindingSyntax="complex" data-sap-ui-compatVersion="edge" \n| &&
    | data-sap-ui-async="true"> \n| &&
    | </script> \n| &&
    | <script> \n| &&
    | sap.ui.require(['sap/ui/core/Core'], (oCore, ) => \{ \n| &&
    | \n| &&
    | sap.ui.getCore().loadLibrary("sap.f", \{ \n| &&
    | async: true \n| &&
    | \}).then(() => \{ \n| &&
    | let shell = new sap.f.ShellBar("shell") \n| &&
    | shell.setTitle("ABAP File Uploader") \n| &&
    | shell.setShowCopilot(true) \n| &&
    | shell.setShowSearch(true) \n| &&
    | shell.setShowNotifications(true) \n| &&
    | shell.setShowProductSwitcher(true) \n| &&
    | shell.placeAt("uiArea") \n| &&
    | sap.ui.getCore().loadLibrary("sap.ui.layout", \{ \n| &&
    | async: true \n| &&
    | \}).then(() => \{ \n| &&
    | let layout = new sap.ui.layout.VerticalLayout("layout") \n| &&
    | layout.placeAt("uiArea") \n| &&
    | let line2 = new sap.ui.layout.HorizontalLayout("line2") \n| &&
    | let line3 = new sap.ui.layout.HorizontalLayout("line3") \n| &&
    | let line4 = new sap.ui.layout.HorizontalLayout("line4") \n| &&
    | sap.ui.getCore().loadLibrary("sap.m", \{ \n| &&
    | async: true \n| &&
    | \}).then(() => \{\}) \n| &&
    | let button = new sap.m.Button("button") \n| &&
    | button.setText("Upload File") \n| &&
    | button.attachPress(function () \{ \n| &&
    | let oFileUploader = oCore.byId("fileToUpload") \n| &&
    | if (!oFileUploader.getValue()) \{ \n| &&
    | sap.m.MessageToast.show("Choose a file first") \n| &&
    | return \n| &&
    | \} \n| &&
    | let oInput = oCore.byId("tablename") \n| &&
    | let oGroup = oCore.byId("grpDataOptions") \n| &&
    | if (!oInput.getValue())\{ \n| &&
    | sap.m.MessageToast.show("Target Table is Required") \n| &&
    | return \n| &&
    | \} \n| &&
    | let param = oCore.byId("uploadParam") \n| &&
    | param.setValue( oInput.getValue() ) \n| &&
    | oFileUploader.getParameters() \n| &&
    | oFileUploader.setAdditionalData(JSON.stringify(\{tablename: oInput.getValue(), \n| &&
    | dataOption: oGroup.getSelectedIndex() \})) \n| &&
    | oFileUploader.upload() \n| &&
    | \}) \n| &&
    | let input = new sap.m.Input("tablename") \n| &&
    | input.placeAt("layout") \n| &&
    | input.setRequired(true) \n| &&
    | input.setWidth("600px") \n| &&
    | input.setPlaceholder("Target ABAP Table") \n| &&
    | input.setShowSuggestion(true) \n| &&
    | input.attachSuggest(function (oEvent)\{ \n| &&
    | jQuery.ajax(\{headers: \{ "sap-table-request": oEvent.getParameter("suggestValue") \n | &&
    | \}, \n| &&
    | error: function(oErr)\{ alert( JSON.stringify(oErr))\}, timeout: 30000, method:"GET",dataType: "json",success: function(myJSON) \{ \n| &&
    " | alert( 'test' ) \n| &&
    | let input = oCore.byId("tablename") \n | &&
    | input.destroySuggestionItems() \n | &&
    | for (var i = 0; i < myJSON.length; i++) \{ \n | &&
    | input.addSuggestionItem(new sap.ui.core.Item(\{ \n| &&
    | text: myJSON[i].TABLE_NAME \n| &&
    | \})); \n| &&
    | \} \n| &&
    | \} \}) \n| &&
    | \}) \n| &&
    | line2.placeAt("layout") \n| &&
    | line3.placeAt("layout") \n| &&
    | line4.placeAt("layout") \n| &&
    | let groupDataOptions = new sap.m.RadioButtonGroup("grpDataOptions") \n| &&
    | let lblGroupDataOptions = new sap.m.Label("lblDataOptions") \n| &&
    | lblGroupDataOptions.setLabelFor(groupDataOptions) \n| &&
    | lblGroupDataOptions.setText("Data Upload Options") \n| &&
    | lblGroupDataOptions.placeAt("line3") \n| &&
    | groupDataOptions.placeAt("line4") \n| &&
    | rbAppend = new sap.m.RadioButton("rbAppend") \n| &&
    | rbReplace = new sap.m.RadioButton("rbReplace") \n| &&
    | rbAppend.setText("Append") \n| &&
    | rbReplace.setText("Replace") \n| &&
    | groupDataOptions.addButton(rbAppend) \n| &&
    | groupDataOptions.addButton(rbReplace) \n| &&
    | rbAppend.setGroupName("grpDataOptions") \n| &&
    | rbReplace.setGroupName("grpDataOptions") \n| &&
    | sap.ui.getCore().loadLibrary("sap.ui.unified", \{ \n| &&
    | async: true \n| &&
    | \}).then(() => \{ \n| &&
    | var fileUploader = new sap.ui.unified.FileUploader( \n| &&
    | "fileToUpload") \n| &&
    | fileUploader.setFileType("json") \n| &&
    | fileUploader.setWidth("400px") \n| &&
    | let param = new sap.ui.unified.FileUploaderParameter("uploadParam") \n| &&
    | param.setName("tablename") \n| &&
    | fileUploader.addParameter(param) \n| &&
    | fileUploader.placeAt("line2") \n| &&
    | button.placeAt("line2") \n| &&
    | fileUploader.setPlaceholder( \n| &&
    | "Choose File for Upload...") \n| &&
    | fileUploader.attachUploadComplete(function (oEvent) \{ \n| &&
    | alert(oEvent.getParameters().response) \n| &&
    | \}) \n| &&
    | \n| &&
    | \}) \n| &&
    | \}) \n| &&
    | \}) \n| &&
    | \}) \n| &&
    | </script> \n| &&
    |</head> \n| &&
    |<body class="sapUiBody"> \n| &&
    | <div id="uiArea"></div> \n| &&
    |</body> \n| &&
    | \n| &&
    |</html> |.
  endmethod.



endclass.
