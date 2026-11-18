$ErrorActionPreference='Stop'
$c=[System.Data.SqlClient.SqlConnection]::new('Data Source=localhost;Initial Catalog=SIS_RAW;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=10');$c.Open()
try{$q=$c.CreateCommand();$q.CommandTimeout=10;$q.CommandText="SELECT COUNT_BIG(*) FROM raw.EventosSQL WHERE estado='PENDIENTE'";$q.ExecuteScalar()}finally{$c.Dispose()}
