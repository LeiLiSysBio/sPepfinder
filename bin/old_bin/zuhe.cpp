#   include <stdio.h>   
#   define maxn 100   
int a[maxn];   


void comb(int   m,int   k)   
{	int   i,j;   
	for   (i=m;i>=k;i--)   
	{	a[k]=i;   
		if   (k>1)   
			comb(i-1,k-1);   
		else   
		{ 
			for   (j=a[0];j>0;j--)   
				printf("%4d",a[j]);   
				printf("\n");   
		}   
	}   
}   

int main()   
{ a[0]=3;   
  comb(5,3);   
  return 1;
}  
