## Mapping MAB > MODS > DC

### Record identifier

#### 001

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

### ~~Related item identifier~~

#### 003 (ignored)

### Language

#### 037ba

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

### Geographical coordinates

#### 034-

Is not mapped into MODS but into a separate datastream called GEO  
If there is nothing in 034- then check 078k

Subfields
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

### Roles and contributors

#### 100/200

Could be:  
100 _ a, 104 a a, 108 a a … 196 a a  
100 b a, 104 b a, 108 b a … 196 b a  
100 _ p, 104 a p, 108 a p … 196 a p  
100 b p, 104 b p, 108 b p … 196 b p  
200 _ a, 204 a a, 208 a a … 296 a a  
200 b a, 204 b a, 208 b a … 296 b a  
200 _ p, 204 a p, 208 a p, 296 a p  
200 b p, 204 b p, 208 b p, 296 b p  

100... persons  
200... corporate entities  

Subfields  
* a - not GND normalized name
* p - GND normalized name (in case of 200 fields /corporate entities/ it's not 'p' but 'k','g' or 'b')
* 9 - GND identifier
* b - role

Role mapping
  
| MAB        | MODS           | Note  |
| ------------- | ------------- | ----- |
| [Bearb.] | edt | # Fällt im Englischen mit editor zusammen |
| [Hrsg.] | edt | |
| [Drucker] | prt | |
| [Ill.] | ill | |
| [Widmungsempfänger] | dte | # drm steht eigentlich für Technischer Zeichner, es gibt aber ansonsten nur Künstler - in beiden Fällen ist etwas anderes gemeint, aber Technischer Zeichner trifft es m.E.n. noch eher |
| [Zeichner] | drm | |
| [Mitarb.] | ctb | |
| [Kartograph] | ctg | |
| [Lithograph] | ltg | |
| [Stecher] | egr | |
  

If the role wasn't found then 
*  If field is 100 and indicator is 'a' or '-' then the role is 'author'
*  If indicator is 'b', the role is 'contributor'

###### Example
```
{
  "id" : "100",
  "subfield" : [ 
    {
      "content" : "Bayer, Michael",
      "label" : "a"
    }, 
    {
      "content" : "[Bearb.]",
      "label" : "b"
    }
  ],
  "i2" : "1",
  "i1" : "b"
}
```

###### MODS
```xml
<mods:name type="personal">
  <mods:namePart type="given">Michael</mods:namePart>
  <mods:namePart type="family">Bayer</mods:namePart>
  <mods:role>
    <mods:roleTerm authority="marcrelator" type="code">edt</mods:roleTerm>
  </mods:role>
</mods:name>
```

###### DC
```xml
<dc:creator>Bayer, Michael</dc:creator>
```

### Titles

| MAB Field        | Subtitle pair field |  MODS title type |
| ------------- | ------------- | ----- |
| 304 | *none* | uniform |
| 310 | *none* | alternative |
| 341 | 343 | translated |
| 345 | 347 | translated |
| 349 | 351 | translated |
| 331 | 335 | *none* |

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
