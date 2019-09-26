class InsightBase
{
    InsightBase () { }

    static [string] GetPSAsciiToHex ( [string]$asciiValue )
    {
        $hexValues = @()

        for ( $i = 1; $i -le $asciiValue.Length; $i++ )
        {
            $stringValue = $asciiValue.SubString( ( $i - 1 ), 1 )

            $hexValues += "{0:X}" -f [byte][char]$stringValue
        }
        
        return [string]::join( "", $hexValues ).ToLower();
    }
}