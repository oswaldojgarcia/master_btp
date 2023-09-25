@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Libros'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
@Metadata.allowExtensions: true
define view entity zog_cds_libros
  as select from    zog_t_libros         as Libros
    inner join      zog_t_categoria      as Categoria on Libros.bi_categ = Categoria.bi_categ
    left outer join zog_cds_clientes_lib as Ventas    on Libros.id_libro = Ventas.IdLibro
    left outer join I_LanguageText       as Idiomas   on Libros.idioma = Idiomas.LanguageCode
  association [0..*] to zog_cds_clientes as _Clientes on $projection.IdLibro = _Clientes.IdLibro
{
  key Libros.id_libro       as IdLibro,
      Libros.titulo         as Titulo,
      Libros.autor          as Autor,
      Libros.bi_categ       as Categoria,
      Categoria.descripcion as DescrCategoria,
      Libros.editorial      as Editorial,
      //      Libros.idioma         as Idioma,
      Idiomas.LanguageName  as Idioma,
      Libros.paginas        as Paginas,
      @Semantics.amount.currencyCode: 'Moneda'
      Libros.precio         as Precio,
      case
          when Ventas.Ventas < 1 then 0     //neutro
          when Ventas.Ventas = 1 then 1     //rojo
          when Ventas.Ventas = 2 then 2     //amarillo
          else 3                            //verde
      end                   as Ventas,
      ''                    as Text,
      Libros.moneda         as Moneda,
      Libros.formato        as Formato,
      Libros.url            as Imagen,
      _Clientes
}
where
  Idiomas.Language = $session.system_language
