## Mapping MAB > MODS > DC

### 001

> Record identifier

###### Example
`AC08790778`

###### MODS
```xml
<mods:identifier type="ac-number">AC08790778</mods:identifier>
```

###### DC
```xml
<dc:identifier>AC08790778</dc:identifier>
```

### ~~003~~ (ignored)

### 037ba

> Language

###### Example
`ger`

###### MODS
```xml
<mods:language>
  <mods:languageTerm authority="iso639-2b" type="code">ger</mods:languageTerm>
</mods:language>
```

###### DC
```xml
<dc:language>ger</dc:language>
```

### 034-

> Geographical coordinates.  
> Is not mapped into MODS but into a separate datastream called GEO  
> If there is nothing in 034- then check 078k

> Subfields
* a - ignore
* b - scale
* d - W
* e - E
* f - N
* g - S

###### Example
```
{
  "subfield" : [ 
    {
      "label" : "a",
      "content" : "a"
    }, 
    {
      "label" : "b",
      "content" : "220000"
    }, 
    {
      "label" : "d",
      "content" : "E0124300"
    }, 
    {
      "label" : "e",
      "content" : "E0151700"
    }, 
    {
      "content" : "N0471200",
      "label" : "f"
    }, 
    {
       "content" : "N0462000",
       "label" : "g"
    }
  ],
  "id" : "078",
  "i2" : "1",
  "i1" : "k"
}
```

###### GEO
```xml
<kml:kml xmlns:kml="http://www.opengis.net/kml/2.2">
  <kml:Document>
    <kml:Placemark>
      <kml:Polygon>
        <kml:outerBoundaryIs>
          <kml:LinearRing>
            <kml:coordinates>46.3333333333333,12.7166666666667,0 46.3333333333333,15.2833333333333,0 47.2,15.2833333333333,0 47.2,12.7166666666667,0</kml:coordinates>
          </kml:LinearRing>
        </kml:outerBoundaryIs>
      </kml:Polygon>
    </kml:Placemark>
  </kml:Document>
</kml:kml>
```

###### DC
```xml
TBD
```
